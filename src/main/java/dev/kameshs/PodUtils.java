package dev.kameshs;

import io.fabric8.kubernetes.api.model.Pod;
import io.fabric8.kubernetes.client.KubernetesClient;
import java.util.Optional;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class PodUtils {

  private static final Logger LOGGER = Logger.getLogger(
    PodUtils.class.getName());

  private final KubernetesClient kubernetesClient;

  public PodUtils(KubernetesClient kubernetesClient) {
    this.kubernetesClient = kubernetesClient;
  }

  public Optional<String> getIstioRevision() {
    try {
      return kubernetesClient.pods()
                             .withLabel("app=istio-multi-rev-demo")
                             .list()
                             .getItems()
                             .stream()
                             .findFirst()
                             .map(pod -> pod.getMetadata()
                                            .getLabels()
                                            .get("istio.io/rev"));
    } catch (Exception e) {
      LOGGER.log(Level.SEVERE, "Error getting Istio revision", e);
    }
    return Optional.of("unknown");
  }

  public Optional<String> getServiceRevision() {
    try {
      return kubernetesClient.pods()
                             .withLabel("app=istio-multi-rev-demo")
                             .list()
                             .getItems()
                             .stream()
                             .findFirst()
                             .map(pod -> pod.getMetadata()
                                            .getLabels()
                                            .get("version"));
    } catch (Exception e) {
      LOGGER.log(Level.SEVERE, "Error getting service revision", e);
    }
    return Optional.of("unknown");
  }
}
