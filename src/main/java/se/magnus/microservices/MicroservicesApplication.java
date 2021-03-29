package se.magnus.microservices;

import java.util.Collections;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

import springfox.documentation.builders.PathSelectors;
import springfox.documentation.builders.RequestHandlerSelectors;
import springfox.documentation.service.ApiInfo;
import springfox.documentation.service.Contact;
import springfox.documentation.spi.DocumentationType;
import springfox.documentation.spring.web.plugins.Docket;
import springfox.documentation.swagger2.annotations.EnableSwagger2;

@SpringBootApplication
@ComponentScan("se.magnus")
@Configuration
@EnableSwagger2
public class MicroservicesApplication {

	private static final Logger LOG = LoggerFactory.getLogger(MicroservicesApplication.class);

	@Value("${api.common.version}")
	String apiVersion;
	@Value("${api.common.title}")
	String apiTitle;
	@Value("${api.common.description}")
	String apiDescription;
	@Value("${api.common.termsOfServiceUrl}")
	String apiTermsOfServiceUrl;
	@Value("${api.common.license}")
	String apiLicense;
	@Value("${api.common.licenseUrl}")
	String apiLicenseUrl;
	@Value("${api.common.contact.name}")
	String apiContactName;
	@Value("${api.common.contact.url}")
	String apiContactUrl;
	@Value("${api.common.contact.email}")
	String apiContactEmail;

	/**
	 * Will exposed on $HOST:$PORT/swagger-ui.html
	 *
	 * @return
	 */
	@Bean
	public Docket apiDocumentation() {

		return new Docket(DocumentationType.SWAGGER_2).select()
				// .apis(RequestHandlerSelectors.basePackage("se.magnus.microservices.composite"))
				.apis(RequestHandlerSelectors.any()).paths(PathSelectors.any()).build().apiInfo(apiInfo());

	}

	private ApiInfo apiInfo() {
		return new ApiInfo(apiTitle, apiDescription, apiVersion, apiTermsOfServiceUrl,
				new Contact(apiContactName, apiContactUrl, apiContactEmail), apiLicense, apiLicenseUrl,
				Collections.emptyList());

	}

	@Bean
	RestTemplate restTemplate() {
		return new RestTemplate();
	}

	public static void main(String[] args) {
		ConfigurableApplicationContext ctx = SpringApplication.run(MicroservicesApplication.class, args);

		String mongoDbHost = ctx.getEnvironment().getProperty("spring.data.mongodb.host");
		String mongoDbPort = ctx.getEnvironment().getProperty("spring.data.mongodb.port");
		LOG.info("Connected to MongoDb: " + mongoDbHost + ":" + mongoDbPort);

		String postgreSqlUri = ctx.getEnvironment().getProperty("spring.datasource.url");
		LOG.info("Connected to PostgreSQL: " + postgreSqlUri);
	}

}
