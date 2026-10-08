package example.quarkus.layered.single;

import io.quarkus.arc.properties.IfBuildProperty;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello/swiss")
@IfBuildProperty(name = "hello.language", stringValue = "swiss")
public class HelloSwiss {

    private static final String GREETING = "Grüezi";

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return GREETING;
    }
}
