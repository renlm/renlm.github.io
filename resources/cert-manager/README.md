# cert-manager

## v1.20.2
	$ helm repo add jetstack https://charts.jetstack.io
	$ helm fetch jetstack/cert-manager --version=v1.20.2
	$ helm pull jetstack/cert-manager --version=v1.20.2 --untar
	$ helm template cert-manager cert-manager --namespace cert-manager --set crds.enabled=true | \
        grep -oP 'image:\s*\K.*' | \
        sed 's/^"//;s/"$//' | \
        sort -u
        