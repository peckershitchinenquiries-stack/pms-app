package uk.co.peckers.app;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.TreeSet;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Identifies which deployment the WebView is running, so a resume can reload
 * deterministically instead of hoping Next.js notices its own build-ID drift.
 *
 * The fingerprint is a hash of every `/_next/static/...` asset path in the
 * document served at server.url. Those paths are content-hashed by the Next.js
 * build, so a new deployment always changes them and a redeploy of the same
 * commit never does. Nothing in the web app has to expose a version endpoint.
 */
class BuildFingerprint {

    private static final String PREFS = "peckers_shell";
    private static final String KEY = "build_fingerprint";

    private static final Pattern ASSET = Pattern.compile("/_next/static/[A-Za-z0-9._/-]+");
    private static final int MAX_BODY_CHARS = 512 * 1024;
    private static final int TIMEOUT_MS = 8000;

    private static final Executor PROBE = Executors.newSingleThreadExecutor();

    private final SharedPreferences prefs;

    BuildFingerprint(Context context) {
        this.prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    /** Record what is on screen now, so a later resume has something to compare. */
    void record(String url) {
        PROBE.execute(() -> {
            String fingerprint = probe(url);
            if (fingerprint != null) prefs.edit().putString(KEY, fingerprint).apply();
        });
    }

    /** Clear the record, so the next probe reseeds rather than reporting a change. */
    void forget() {
        prefs.edit().remove(KEY).apply();
    }

    /**
     * Compare the deployed fingerprint with the recorded one. `onChanged` runs
     * only on a confirmed difference — an unreachable server, a page with no
     * Next.js assets, or no recorded baseline all leave the WebView alone.
     */
    void checkForChange(String url, Runnable onChanged) {
        PROBE.execute(() -> {
            String current = probe(url);
            if (current == null) return;

            String previous = prefs.getString(KEY, null);
            prefs.edit().putString(KEY, current).apply();

            if (previous != null && !previous.equals(current)) onChanged.run();
        });
    }

    private static String probe(String url) {
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(url).openConnection();
            connection.setInstanceFollowRedirects(true);
            connection.setConnectTimeout(TIMEOUT_MS);
            connection.setReadTimeout(TIMEOUT_MS);
            connection.setRequestProperty("Accept", "text/html");
            connection.setRequestProperty("Cache-Control", "no-cache");

            if (connection.getResponseCode() >= 400) return null;

            TreeSet<String> assets = new TreeSet<>();
            int read = 0;
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null && read < MAX_BODY_CHARS) {
                    read += line.length();
                    Matcher matcher = ASSET.matcher(line);
                    while (matcher.find()) assets.add(matcher.group());
                }
            }

            if (assets.isEmpty()) return null;
            return sha256(String.join("\n", assets));
        } catch (Exception e) {
            return null;
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    private static String sha256(String input) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(input.getBytes("UTF-8"));
        StringBuilder hex = new StringBuilder(digest.length * 2);
        for (byte b : digest) hex.append(String.format(Locale.US, "%02x", b));
        return hex.toString();
    }
}
