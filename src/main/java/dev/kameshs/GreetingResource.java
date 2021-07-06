package dev.kameshs;

import java.util.Optional;
import java.util.logging.Logger;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
public class GreetingResource {

  private static final String RESPONSE_STRING_FORMAT = "HelloWorld  %s from greeting service '%s': %d";

  private static final Logger logger = Logger.getLogger(
    GreetingResource.class.getName());

  private final PodUtils podUtils;

  private int count = 0;

  private static final String HOSTNAME = System.getenv()
                                               .getOrDefault("HOSTNAME",
                                                 "unknown");

  public GreetingResource(PodUtils podUtils) {
    this.podUtils = podUtils;
  }

  @GET
  @Path("/hello")
  public Response hello() {
    count++;
    logger.info(
      String.format("recommendation request from %s: %d", HOSTNAME, count));

    GreetingResponse response = new GreetingResponse();
    Optional<String> serviceRevision = podUtils.getServiceRevision();
    Optional<String> istioRevision = podUtils.getIstioRevision();
    response.serviceRevison = serviceRevision.orElseThrow();
    response.istioRevision = istioRevision.orElse("unknown");
    response.message = String.format(RESPONSE_STRING_FORMAT, HOSTNAME,
      response.serviceRevison, count);
    return Response.ok()
                   .entity(response)
                   .build();
  }
}
