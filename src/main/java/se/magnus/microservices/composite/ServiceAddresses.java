package se.magnus.microservices.composite;

public class ServiceAddresses {
    private final String productCompositeServiceAddress;

    public ServiceAddresses() {
        productCompositeServiceAddress = null;
    }

    public ServiceAddresses(String productCompositeServiceAddress) {
        this.productCompositeServiceAddress = productCompositeServiceAddress;
    }

    public String getProductCompositeServiceAddress() {
        return productCompositeServiceAddress;
    }

}
