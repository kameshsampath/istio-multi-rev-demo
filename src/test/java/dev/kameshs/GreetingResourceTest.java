package dev.kameshs;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;

@QuarkusTest
public class GreetingResourceTest {

  @Test
  public void testHelloEndpoint() {
    GreetingResponse expectedResponse = new GreetingResponse();
    expectedResponse.serviceRevison = "unknown";
    expectedResponse.istioRevision = "unknown";
    expectedResponse.message = "HelloWorld  unknown from 'unknown': 1\n";
    GreetingResponse actualResponse = given()
        .when()
        .get("/api/hello")
        .then()
        .statusCode(200)
        .extract()
        .response()
        .as(GreetingResponse.class);

    assertEquals(expectedResponse, actualResponse);
  }

}