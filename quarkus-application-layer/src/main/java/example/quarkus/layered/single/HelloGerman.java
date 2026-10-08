package example.quarkus.layered.single;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello/german")
public class HelloGerman {

    private static final String GREETING = "Hallo";

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return GREETING;
    }
}
