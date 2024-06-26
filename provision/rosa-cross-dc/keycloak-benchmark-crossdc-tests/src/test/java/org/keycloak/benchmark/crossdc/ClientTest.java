package org.keycloak.benchmark.crossdc;

import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import org.keycloak.admin.client.Keycloak;
import org.keycloak.admin.client.resource.RealmResource;
import org.keycloak.benchmark.crossdc.client.KeycloakClient;
import org.keycloak.representations.idm.ClientRepresentation;
import org.keycloak.representations.idm.RealmRepresentation;

import java.net.CookieManager;
import java.net.http.HttpClient;
import java.util.List;
import java.util.stream.Collectors;

public class ClientTest {

    private static final String REALM_NAME = "client-test-realm";
    private static final String CLIENT_ID = "client-test-id";
    private static final String CLIENT_SECRET = "client-test-secret";

    @Test
    public void testClients() {
        var httpClient = newHttpClient();
        try {
            var dc1 = new KeycloakClient(httpClient, "http://127.0.0.1:8080", false);
            var dc2 = new KeycloakClient(httpClient, "http://127.0.0.1:8081", false);

            removeRealm(dc1.adminClient());

            var realmResource = createRealm(dc1.adminClient());

            createClient(realmResource);

            findClient("site-1", realmResource);
            findClient("site-2", dc2.adminClient().realm(REALM_NAME));

            System.out.println("Remove realm and retry");

            removeRealm(dc1.adminClient());
            realmResource = createRealm(dc1.adminClient());

            createClient(realmResource);

            findClient("site-1", realmResource);
            findClient("site-2", dc2.adminClient().realm(REALM_NAME));
        } finally {
            KeycloakClient.cleanAdminClients();
        }
    }

    private static void removeRealm(Keycloak adminClient) {
        try {
            if (adminClient.realms().realm(REALM_NAME).toRepresentation() != null) {
                adminClient.realms().realm(REALM_NAME).remove();
                System.out.println("Realm Removed: " + REALM_NAME);
            }
        } catch (NotFoundException e) {
            // Ignore
        }
    }

    private static RealmResource createRealm(Keycloak adminClient) {
        var realm = new RealmRepresentation();
        realm.setRealm(REALM_NAME);
        realm.setEnabled(Boolean.TRUE);
        adminClient.realms().create(realm);
        System.out.println("Realm created: " + REALM_NAME);
        return adminClient.realm(REALM_NAME);
    }

    private static void createClient(RealmResource realmResource) {
        // Create client
        ClientRepresentation client = new ClientRepresentation();
        client.setEnabled(Boolean.TRUE);
        client.setClientId(CLIENT_ID);
        client.setSecret(CLIENT_SECRET);
        client.setRedirectUris(List.of("*"));
        client.setDirectAccessGrantsEnabled(true);
        client.setProtocol("openid-connect");
        realmResource.clients().create(client).close();
        System.out.printf("Client created: ID=%s, REALM=%s%n", CLIENT_ID, REALM_NAME);
    }

    private static void findClient(String site, RealmResource realmResource) {
        var client = realmResource.clients().findByClientId(CLIENT_ID).iterator().next();
        System.out.printf("[%s] client: REALM=%s, ID=%s, UUID=%s%n", site, REALM_NAME, client.getClientId(), client.getId());
    }

    private static HttpClient newHttpClient() {
        return HttpClient.newBuilder()
                .cookieHandler(new CookieManager())
                .version(HttpClient.Version.HTTP_2)
                .build();
    }

}
