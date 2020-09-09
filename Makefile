
build:
	docker run --rm --privileged -v /dev:/dev -v ${HOME}/.local/aarch64:/build/bin -v ${PWD}:/build packer-builder-arm build pi-ubuntu-arm64.json

clean:
