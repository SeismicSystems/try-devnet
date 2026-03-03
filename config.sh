#!/bin/bash

# Source all configuration from .env
if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
fi
