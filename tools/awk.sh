awk '
BEGIN { output=0 }
/^apiVersion: orchestration.sas.com\/v1alpha1/ { 
    print "---"
    output=1
}
output {
    if ($0 ~ /^  license:/) {
        print $0
        print "    secretKeyRef:"
        print "      key: license"
        print "      name: sas-viya"
        getline # Saute la ligne contenant l"ancienne url
        next
    }
    print $0
}' viya-sasdeployment.yaml > viya-sasdeployment.yaml.fixed
