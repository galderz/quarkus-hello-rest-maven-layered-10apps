package example.quarkus.layered.single;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello/english")
public class HelloEnglish {

    private static final String GREETING = "Hello";

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return GREETING;
    }
}
