package dev.kameshs;

import java.util.Objects;

public class GreetingResponse {

  public String istioRevision;
  public String serviceRevison;
  public String message;

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }
    GreetingResponse that = (GreetingResponse) o;
    return istioRevision.equals(that.istioRevision) && serviceRevison.equals(
        that.serviceRevison) && message.equals(that.message);
  }

  @Override
  public int hashCode() {
    return Objects.hash(istioRevision, serviceRevison, message);
  }
}
