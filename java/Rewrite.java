import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

// Java 17+, no dependencies: DOCINFRA_API_KEY=doc_live_... java Rewrite.java
public class Rewrite {

    public static void main(String[] args) throws Exception {
        String apiKey = System.getenv("DOCINFRA_API_KEY");
        if (apiKey == null || apiKey.isBlank()) {
            System.err.println("Set DOCINFRA_API_KEY first.");
            System.exit(1);
        }
        String baseUrl = System.getenv().getOrDefault("DOCINFRA_BASE_URL", "https://api.apidocinfra.com");

        String text = "It is important to note that Northwind Analytics closed Q3 with revenue of $2.4 million, "
                + "up 18.5% from Q2. The board will review these results on October 15, 2026. "
                + "The full report is available at https://example.com/reports/q3-2026 for all stakeholders.";

        String json = """
                {
                  "text": "%s",
                  "mode": "professional",
                  "intensity": "medium",
                  "language": "auto",
                  "protected_terms": ["Northwind Analytics"]
                }
                """.formatted(escape(text));

        HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        HttpRequest request = HttpRequest.newBuilder(URI.create(baseUrl + "/v1/text/rewrite"))
                .timeout(Duration.ofSeconds(150))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        System.out.println("HTTP " + response.statusCode());
        System.out.println(response.body());
        if (response.statusCode() != 200) {
            System.exit(1);
        }
    }

    private static String escape(String value) {
        StringBuilder out = new StringBuilder();
        for (char c : value.toCharArray()) {
            switch (c) {
                case '"' -> out.append("\\\"");
                case '\\' -> out.append("\\\\");
                case '\n' -> out.append("\\n");
                case '\r' -> out.append("\\r");
                case '\t' -> out.append("\\t");
                default -> {
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
                }
            }
        }
        return out.toString();
    }
}
