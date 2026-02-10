VERSION := $(shell cat VERSION | tr -d '[:space:]')
TARBALL := build-toolkit-$(VERSION).tar.gz
DIST_DIR := build-toolkit

.PHONY: dist release clean

dist: clean
	@echo "Building $(TARBALL)..."
	@mkdir -p $(DIST_DIR)
	@cp -r config.sh menu.sh banner.txt install.sh uninstall.sh VERSION scripts $(DIST_DIR)/
	@tar czf $(TARBALL) $(DIST_DIR)
	@rm -rf $(DIST_DIR)
	@echo "Created $(TARBALL)"

release: dist
	gh release create v$(VERSION) $(TARBALL) \
		--title "v$(VERSION)" \
		--generate-notes

clean:
	@rm -rf $(DIST_DIR) build-toolkit-*.tar.gz
