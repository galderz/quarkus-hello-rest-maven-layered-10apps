package example.quarkus.layered.single;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello/ukrainian")
public class HelloUkrainian {

    private static final String GREETING = "Привіт";

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return GREETING;
    }
}
