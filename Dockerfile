FROM grafana/grafana:11.0.0
COPY https-certs/ /etc/certs
USER root
RUN chown -R 472:472 /etc/certs
