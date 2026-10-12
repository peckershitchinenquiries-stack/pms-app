package uk.co.peckers.app;

import android.os.Bundle;
import android.webkit.CookieManager;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AlertDialog;
import com.getcapacitor.Bridge;
import com.getcapacitor.BridgeActivity;
import com.getcapacitor.BridgeWebViewClient;
import com.getcapacitor.WebViewListener;

public class MainActivity extends BridgeActivity {

    // A resume sooner than this is an app switch, not a return to a stale app.
    private static final long VERSION_CHECK_AFTER_MS = 60_000L;
    // Long enough away that reloading is right whether or not the deploy moved.
    private static final long FORCE_RELOAD_AFTER_MS = 12 * 60 * 60 * 1000L;

    private OfflineGate offline;
    private BuildFingerprint fingerprint;
    private AlertDialog exitDialog;
    private long backgroundedAt = 0L;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        registerBackHandler();
    }

    @Override
    protected void load() {
        super.load();

        fingerprint = new BuildFingerprint(this);
        offline = new OfflineGate(this, bridge);
        bridge.setWebViewClient(new ShellWebViewClient(bridge));
        bridge.addWebViewListener(
            new WebViewListener() {
                @Override
                public void onPageLoaded(WebView view) {
                    fingerprint.record(serverUrl());
                }
            }
        );

        if (!offline.hasNetwork()) offline.show();
    }

    /**
     * Back navigates the WebView and only offers to leave once there is no
     * history left - which is the landing screen, whichever portal it is. The
     * shell deliberately knows no route names: that is the web app's business.
     */
    private void registerBackHandler() {
        getOnBackPressedDispatcher()
            .addCallback(
                this,
                new OnBackPressedCallback(true) {
                    @Override
                    public void handleOnBackPressed() {
                        WebView webView = bridge == null ? null : bridge.getWebView();
                        boolean blocked = offline != null && offline.isShowing();
                        if (webView != null && !blocked && webView.canGoBack()) {
                            webView.goBack();
                            return;
                        }
                        confirmExit();
                    }
                }
            );
    }

    private void confirmExit() {
        if (exitDialog != null && exitDialog.isShowing()) return;
        exitDialog = new AlertDialog.Builder(this)
            .setTitle(R.string.exit_title)
            .setMessage(R.string.exit_message)
            .setNegativeButton(R.string.exit_cancel, null)
            .setPositiveButton(R.string.exit_confirm, (dialog, which) -> finish())
            .show();
    }

    private String serverUrl() {
        String url = bridge.getServerUrl();
        return url == null || url.trim().isEmpty() ? bridge.getAppUrl() : url;
    }

    @Override
    public void onResume() {
        super.onResume();
        if (offline == null) return;
        offline.startWatching();

        long awayMs = backgroundedAt == 0L ? 0L : System.currentTimeMillis() - backgroundedAt;
        backgroundedAt = 0L;

        if (!offline.hasNetwork()) {
            offline.show();
            return;
        }
        if (offline.isShowing()) {
            offline.retry();
            return;
        }

        if (awayMs >= FORCE_RELOAD_AFTER_MS) {
            fingerprint.forget();
            offline.reload();
        } else if (awayMs >= VERSION_CHECK_AFTER_MS) {
            fingerprint.checkForChange(serverUrl(), () -> offline.reload());
        }
    }

    @Override
    public void onPause() {
        super.onPause();
        // The session is a persistent cookie in the WebView's store, which is
        // only written to disk periodically. Without this flush a force-stop or
        // a kill can lose a login that happened seconds earlier.
        CookieManager.getInstance().flush();
    }

    @Override
    public void onStop() {
        super.onStop();
        backgroundedAt = System.currentTimeMillis();
        if (offline != null) offline.stopWatching();
    }

    /** Main-frame network failures only, so a failed subresource shows nothing. */
    private class ShellWebViewClient extends BridgeWebViewClient {

        private boolean mainFrameFailed = false;

        ShellWebViewClient(Bridge bridge) {
            super(bridge);
        }

        @Override
        public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
            mainFrameFailed = false;
            super.onPageStarted(view, url, favicon);
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            if (request.isForMainFrame()) {
                mainFrameFailed = true;
                offline.show();
            }
            super.onReceivedError(view, request, error);
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            super.onPageFinished(view, url);
            if (!mainFrameFailed) offline.hide();
        }
    }
}
