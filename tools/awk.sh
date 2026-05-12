awk '
/^apiVersion: orchestration.sas.com\/v1alpha1/ { 
    output=1
    print "---"
}
output {
    if ($0 ~ /^  license:/) {
        print $0
        print "    secretKeyRef:"
        print "      key: license"
        print "      name: sas-viya"
        getline # Saute l"ancienne ligne contenant l"url
        next
    }
    print $0
}' viya-sasdeployment.yaml > viya-sasdeployment.yaml.fixed
