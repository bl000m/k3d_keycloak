#!/bin/bash

 #############################################################################

# @(#) 
# @(#) Name: x509csr.sh
# @(#) 
# @(#) Usage:   x509csr [help|-help|--help|-h]  
# @(#) 
# @(#) Description: 
# @(#)
# @(#) Comments: For any comments, please contact <csr@cc.in2p3.fr>
# @(#)
# @(#)             Centre de Calcul de l'IN2P3 - (c) 2020
# @(#)

 #############################################################################

 PATH=/bin:/sbin:/usr/bin:/usr/sbin
 export PATH

 SNAME="`basename $0`"

 VERSION="v1.0"

 #############################################################################

 usage_help ()
 {
    echo 
    echo "Usage: ${SNAME} <FQDN1> [<FQDN2> <FQDN3>...]"
    echo 
    echo "        Where FQDN is(are) the Fully Qualified Domain Name(s) of"
    echo "        the server for which the CSR is to be generated."
    echo
    return 1
 }

 #############################################################################

 csrgen_unidomain ()
 {
   FQDN="${1}"
   FILENAME="`echo ${FQDN} | sed 's/\./_/g'`"
   openssl req	-new \
		-newkey rsa:4096 \
		-sha384 \
		-nodes \
		-subj "/CN=${FQDN}" \
		-keyout ${FILENAME}.key \
		-out ${FILENAME}.csr
   return $?
 }	

 #############################################################################

 csrgen_multidomain ()
 {
   FQDN="${1}"
   FILENAME="`echo ${FQDN} | sed 's/\./_/g'`"

   N=1 ; echo > ${FILENAME}.SAN

   for i in "$@"
   do
      if [ "$i" != "${FQDN}" ];then
          printf "DNS.%d\t= %s\n" ${N} ${i} >> ${FILENAME}.SAN
          let N=N+1
      fi
   done

cat << EOF > ${FILENAME}-openssl.cnf
[req]
distinguished_name      = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
commonName = ${FQDN}

[v3_req]
# Extensions to add to a certificate request
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
`cat ${FILENAME}.SAN`

EOF

   openssl genrsa -out ${FILENAME}.key 4096
   openssl req	-new \
		-sha384 \
		-subj "/CN=${FQDN}" \
		-out ${FILENAME}.csr \
		-key ${FILENAME}.key \
		-config ${FILENAME}-openssl.cnf

   rm -f ${FILENAME}-openssl.cnf ${FILENAME}.SAN
   return 0
 }
 
 #############################################################################

 case $# in
        0)
           usage_help
           exit 1
           ;;

        1)
	   case $1 in
		help|-help|--help|-h)
		   usage_help
		   exit 1
		   ;;

		*)
           	   csrgen_unidomain ${1}
		   ;;
	   esac
           ;;

        *)
           csrgen_multidomain $@
           ;;
 esac

 # This is the end folks !
 exit 0
