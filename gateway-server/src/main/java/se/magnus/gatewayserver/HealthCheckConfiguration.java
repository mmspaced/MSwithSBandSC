package se.magnus.gatewayserver;

import java.util.LinkedHashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.actuate.health.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

import reactor.core.publisher.Mono;

@Configuration
public class HealthCheckConfiguration {

    private static final Logger LOG = LoggerFactory.getLogger(HealthCheckConfiguration.class);

    private final WebClient.Builder webClientBuilder;
    private WebClient webClient;

    @Autowired
    public HealthCheckConfiguration(
        WebClient.Builder webClientBuilder
        // HealthAggregator healthAggregator
    ) {
        this.webClientBuilder = webClientBuilder;
        // this.healthAggregator = healthAggregator;
    }

    @Bean
    ReactiveHealthContributor healthcheckMicroservices() {

        final Map<String, ReactiveHealthIndicator> registry = new LinkedHashMap<>();

        registry.put("auth-server",       () -> getHealth("http://auth-server"));
        registry.put("product",           () -> getHealth("http://product"));
        registry.put("recommendation",    () -> getHealth("http://recommendation"));
        registry.put("review",            () -> getHealth("http://review"));
        registry.put("product-composite", () -> getHealth("http://product-composite"));

        // System.out.println("The health check results from product-composite are: " + getHealth("http://product-composite").toString());

        return CompositeReactiveHealthContributor.fromMap(registry);          
   	}

    private Mono<Health> getHealth(String url) {
        url += "/actuator/health";
        LOG.debug("Will call the Health API on URL: {}", url);
        return getWebClient().get().uri(url).retrieve().bodyToMono(String.class).map(s -> new Health.Builder().up().build()).onErrorResume(ex -> Mono.just(new Health.Builder().down(ex).build())).log();
    }

    private WebClient getWebClient() {
        if (webClient == null) {
            webClient = webClientBuilder.build();
        }
        return webClient;
    }
}