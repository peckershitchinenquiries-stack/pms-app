package uk.co.peckers.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.webkit.CookieManager;
import android.webkit.RenderProcessGoneDetail;
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
    // A second renderer loss this soon after a recovery is a page that kills it
    // on load; recreating again would loop for ever, so the app closes instead.
    private static final long RENDERER_CRASH_LOOP_MS = 15_000L;

    // Static: recreate() builds a new activity instance, and the guard has to
    // survive it.
    private static long lastRendererRecoveryAt = 0L;

    private OfflineGate offline;
    private BuildFingerprint fingerprint;
    private AlertDialog exitDialog;
    private long backgroundedAt = 0L;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        registerBackHandler();
        createReminderChannel();
    }

    /**
     * The channel the manifest names as FCM's default. FCM only uses a default
     * channel that already exists, else it falls back to "Miscellaneous", so it
     * is created at launch. Idempotent: an existing channel keeps whatever the
     * user changed in settings.
     */
    private void createReminderChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager == null) return;
        NotificationChannel channel = new NotificationChannel(
            getString(R.string.reminder_channel_id),
            getString(R.string.reminder_channel_name),
            NotificationManager.IMPORTANCE_HIGH
        );
        channel.setDescription(getString(R.string.reminder_channel_description));
        manager.createNotificationChannel(channel);
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

                // Without a listener returning true, Android kills the whole
                // app when the WebView's renderer dies (low memory, often while
                // the camera is open for a profile photo). The dead WebView can
                // never draw again, so the activity is rebuilt with a new one.
                @Override
                public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
                    long now = SystemClock.elapsedRealtime();
                    boolean looping = lastRendererRecoveryAt != 0L && now - lastRendererRecoveryAt < RENDERER_CRASH_LOOP_MS;
                    lastRendererRecoveryAt = now;
                    runOnUiThread(looping ? MainActivity.this::finish : MainActivity.this::recreate);
                    return true;
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
