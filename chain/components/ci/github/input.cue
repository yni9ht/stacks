package github

import (
	"universe.dagger.io/docker"
)

#Input: {
	name:         string
	image:        docker.#Image
	organization: string | *""
	deployRepo:   string | *""
	action:       """
		name: Create and publish a Docker image
		on:
		  push:
		    branches: ['main']
		    tags: 
		      - v*
		env:
		  REGISTRY: ghcr.io
		  IMAGE_NAME: ${{ github.repository }}
		  ORG: \(organization)
		  HELM_REPO: \(deployRepo)
		jobs:
		  build-and-push-image:
		    runs-on: ubuntu-latest
		    permissions:
		      contents: read
		      packages: write
		    steps:
		      - name: Checkout repository
		        uses: actions/checkout@v2
		      - name: Set output
		        id: vars
		        run: echo ::set-output name=tag::${GITHUB_REF#refs/*/}
		      - name: Log in to the Container registry
		        uses: docker/login-action@f054a8b539a109f9f41c372932f1ae047eff08c9
		        with:
		          registry: ${{ env.REGISTRY }}
		          username: ${{ github.actor }}
		          password: ${{ secrets.GITHUB_TOKEN }}
		      - name: Extract metadata (tags, labels) for Docker
		        id: meta
		        uses: docker/metadata-action@98669ae865ea3cffbcbaa878cf57c20bbf1c6c38
		        with:
		          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
		      - name: Build and push Docker image
		        uses: docker/build-push-action@ad44023a93711e3deb337508980b4b5e9bcdc5dc
		        with:
		          context: .
		          push: true
		          tags: ${{ steps.meta.outputs.tags }}
		          labels: ${{ steps.meta.outputs.labels }}
		      - name: Checkout Helm chart repo
		        id: checkout_helm
		        uses: actions/checkout@master
		        if: startsWith(github.ref, 'refs/tags/v')
		        with:
		          repository: ${{ env.ORG }}/${{ env.HELM_REPO }}
		          ref: refs/heads/main
		          persist-credentials: false
		          fetch-depth: 0
		          token: ${{ secrets.PAT }}
		      - name: Update helm values
		        uses: mikefarah/yq@master
		        if: startsWith(github.ref, 'refs/tags/v')
		        with:
		          cmd: yq -i '.image.tag = "${{ steps.vars.outputs.tag }}"' ./${{ github.event.repository.name }}/values.yaml
		      - name: Update helm repo
		        if: startsWith(github.ref, 'refs/tags/v')
		        run: |
		          git config user.email "h8r@robot.dev"
		          git config user.name "h8r-robot"
		          git remote set-url origin https://${{ env.ORG }}:${{ secrets.PAT }}@github.com/${{ env.ORG }}/${{ env.HELM_REPO }}.git
		          git add .
		          git commit -m "update images tag ${{ steps.vars.outputs.tag }}"
		          git push
		"""
}
