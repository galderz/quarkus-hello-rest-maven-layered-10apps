package example.quarkus.layered.single;

import io.quarkus.arc.properties.IfBuildProperty;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello/german")
@IfBuildProperty(name = "hello.language", stringValue = "german")
public class HelloGerman {

    private static final String GREETING = "Hallo";

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return GREETING;
    }
}
