container_registry := quay.io/nordstrom
container_name := aws-node-labels
container_release := 1.0

.PHONY: build/image tag/image push/image

build/image:
	docker build \
		-t $(container_name) .

tag/image: build/image
	docker tag $(container_name) $(container_registry)/$(container_name):$(container_release)

push/image: tag/image
	docker push $(container_registry)/$(container_name):$(container_release)