#!/bin/sh

cd /opt/tmpapp
/opt/activator/activator playGenerateSecret | grep "Generated new secret" | cut -d " " -f5