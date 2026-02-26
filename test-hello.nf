#!/usr/bin/env nextflow

process sayHello {
    output:
    stdout

    script:
    """
    echo "Hello from AWS Batch!"
    python3 --version
    echo "Python location: \$(which python3)"
    echo "Checking CA certificates:"
    ls -la /etc/ssl/certs/ca-certificates.crt
    echo "Testing Python requests import:"
    python3 -c "import requests; print('requests version:', requests.__version__)"
    """
}

workflow {
    sayHello | view
}
