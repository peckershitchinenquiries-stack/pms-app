package uk.co.peckers.app;

import android.app.Activity;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import com.getcapacitor.Bridge;

/**
 * Covers the WebView with a native retry screen whenever the page cannot load.
 */
class OfflineGate {

    private final Activity activity;
    private final Bridge bridge;
    private final Handler main = new Handler(Looper.getMainLooper());

    private final View overlay;
    private final TextView body;
    private final ConnectivityManager connectivity;
    private ConnectivityManager.NetworkCallback networkCallback;

    OfflineGate(Activity activity, Bridge bridge) {
        this.activity = activity;
        this.bridge = bridge;
        this.connectivity = (ConnectivityManager) activity.getSystemService(Context.CONNECTIVITY_SERVICE);

        ViewGroup content = activity.findViewById(android.R.id.content);
        LayoutInflater.from(activity).inflate(R.layout.offline_overlay, content, true);
        overlay = content.findViewById(R.id.offline_overlay);
        body = overlay.findViewById(R.id.offline_body);
        overlay.findViewById(R.id.offline_retry).setOnClickListener(v -> retry());
    }

    boolean isShowing() {
        return overlay.getVisibility() == View.VISIBLE;
    }

    void show() {
        main.post(() -> {
            body.setText(R.string.offline_body);
            overlay.setVisibility(View.VISIBLE);
            overlay.bringToFront();
        });
    }

    void hide() {
        main.post(() -> overlay.setVisibility(View.GONE));
    }

    /** True when the device holds a validated internet-capable network. */
    boolean hasNetwork() {
        if (connectivity == null) return true;
        Network active = connectivity.getActiveNetwork();
        if (active == null) return false;
        NetworkCapabilities caps = connectivity.getNetworkCapabilities(active);
        return caps != null && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
    }

    /** Reload server.url, or say so again if the device still has no network. */
    void retry() {
        if (!hasNetwork()) {
            main.post(() -> body.setText(R.string.offline_body_still));
            return;
        }
        hide();
        reload();
    }

    void reload() {
        main.post(() -> {
            String url = bridge.getServerUrl();
            if (url == null || url.trim().isEmpty()) url = bridge.getAppUrl();
            bridge.getWebView().loadUrl(url);
        });
    }

    /** Auto-recover the moment a network comes back while the screen is up. */
    void startWatching() {
        if (connectivity == null || networkCallback != null) return;
        networkCallback = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onAvailable(Network network) {
                if (isShowing()) retry();
            }
        };
        try {
            connectivity.registerDefaultNetworkCallback(networkCallback);
        } catch (RuntimeException e) {
            networkCallback = null;
        }
    }

    void stopWatching() {
        if (connectivity == null || networkCallback == null) return;
        try {
            connectivity.unregisterNetworkCallback(networkCallback);
        } catch (IllegalArgumentException ignored) {
            // Already unregistered
        }
        networkCallback = null;
    }
}
