#!/bin/bash

CERT_FILE=$(mktemp)
CHAIN_FILE=$(mktemp)

# https://tex2e.github.io/blog/shell/tmpfile-best-practice
function rm_tmpfile {
  [[ -f "$CERT_FILE" ]] && rm -f "$CERT_FILE"
  [[ -f "$CHAIN_FILE" ]] && rm -f "$CHAIN_FILE"
}

# 正常終了したとき
trap rm_tmpfile EXIT
# 異常終了したとき
trap 'trap - EXIT; rm_tmpfile; exit -1' INT PIPE TERM

DOMAIN=$1
openssl s_client -connect ${DOMAIN}:443 2>&1 < /dev/null | sed -n '/-----BEGIN/,/-----END/p' > ${CERT_FILE}
# first ceret ignroe
# https://stackoverflow.com/questions/148451/how-to-use-sed-to-replace-only-the-first-occurrence-in-a-file
openssl s_client -connect ${DOMAIN}:443 -showcerts 2>&1 < /dev/null | sed '0,/-----BEGIN/{s/BEGIN CERTIFICATE//}'  | sed -n '/-----BEGIN/,/-----END/p' > ${CHAIN_FILE}

echo OCSP URL
OCSP_URL=$(openssl x509 -noout -ocsp_uri -in ${CERT_FILE})
OCSP_HEADER=$(echo "${OCSP_URL}" |sed -e 's;.*/;HOST=;g')
echo $OCSP_URL
echo openssl
# openssl ocsp -issuer ${CHAIN_FILE} -cert ${CERT_FILE} -text -url ${OCSP_URL} -header \"${OCSP_HEADER}\"
openssl ocsp -noverify -no_nonce -issuer ${CHAIN_FILE} -cert ${CERT_FILE} -url ${OCSP_URL} -header \"${OCSP_HEADER}\"
