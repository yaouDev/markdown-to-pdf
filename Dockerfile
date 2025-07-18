# base package - maintained which is nice
FROM pandoc/latex

WORKDIR /app

# pandoc/latex uses alpine (sh) but the script uses bash, so get it
RUN apk update && apk add bash

COPY entrypoint.sh /entrypoint.sh
COPY template/ /app/template/

# clean line endings
RUN sed -i 's/\r$//' /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
