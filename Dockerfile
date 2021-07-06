FROM alpine:latest

RUN apk update && apk add py3-pip
RUN pip3 install -q Flask==2.0.1 pyyaml kubernetes

RUN mkdir -p /app

COPY service.py /app
CMD ["python3", "/app/service.py"]
