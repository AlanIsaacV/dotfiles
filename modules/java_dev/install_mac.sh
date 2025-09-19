#!/bin/bash

brew install --cask temurin@21
brew install --cask temurin@17
brew install maven
brew install jenv

jenv add /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
jenv add /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
