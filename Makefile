ID := io.github.hephaestuszero.ocxplasma
VERSION := 0.1.0
PKG := ocx-plasma-$(VERSION).plasmoid
DOMAIN := plasma_applet_$(ID)
QMLTESTS := tests/tst_drag.qml tests/tst_rows.qml

.PHONY: test lint locale package install uninstall run clean

test:
	python3 tests/test_collector.py
	@TR=$$(command -v qmltestrunner6 || { [ -x /usr/lib/qt6/bin/qmltestrunner ] && echo /usr/lib/qt6/bin/qmltestrunner; }); \
	if [ -n "$$TR" ]; then \
		for t in $(QMLTESTS); do \
			QT_QPA_PLATFORM=offscreen $$TR -input $$t || exit 1; \
		done; \
	else \
		echo "Qt6 qmltestrunner not found — skipping QML tests"; \
	fi

lint:
	@LINT=$$(command -v qmllint6 || { [ -x /usr/lib/qt6/bin/qmllint ] && echo /usr/lib/qt6/bin/qmllint; } || command -v qmllint); \
	if [ -n "$$LINT" ]; then \
		$$LINT contents/ui/*.qml contents/config/config.qml; \
	else \
		echo "qmllint not found — skipping"; \
	fi

# Compile every po/*.po into the applet translation domain inside contents/locale.
locale:
	@for p in po/*.po; do \
		[ -e "$$p" ] || continue; \
		l=$$(basename $$p .po); \
		mkdir -p contents/locale/$$l/LC_MESSAGES; \
		msgfmt -o contents/locale/$$l/LC_MESSAGES/$(DOMAIN).mo $$p; \
		echo "  locale $$l"; \
	done

package: locale
	rm -f $(PKG)
	zip -qr $(PKG) metadata.json contents -x '*/__pycache__/*'
	@unzip -l $(PKG) | grep -E "metadata.json|ocx_pools.py|\.mo" && echo "built $(PKG)"

install: package
	@kpackagetool6 -t Plasma/Applet -u $(PKG) 2>/dev/null \
		|| kpackagetool6 -t Plasma/Applet -i $(PKG)
	@echo "Installed. Add 'OCX Quota' to a panel or the desktop."

uninstall:
	kpackagetool6 -t Plasma/Applet -r $(ID)

# Run the widget in a test window. plasmawindowed caches QML — drop the cache first.
run: install
	rm -rf ~/.cache/plasmawindowed
	plasmawindowed $(ID)

clean:
	rm -f $(PKG)
	rm -rf contents/locale contents/code/__pycache__ tests/__pycache__
