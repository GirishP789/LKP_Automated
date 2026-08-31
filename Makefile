# Makefile to set all files in the current directory to executable

# Target to set executable permissions
all:
	chmod 777 *
	./run.sh

# Reverses everything run.sh/lkp-deps.sh created (lkp-tests clones, test
# results, generated automation scripts/logs, and auto_lkp.service if it
# exists), regardless of whether the VM or Host option was used. OS
# packages installed via apt/dnf are left installed. See uninstall.sh.
uninstall:
	chmod +x uninstall.sh
	./uninstall.sh

# Clean target (optional, if you want to add a clean-up function)
clean:
	@echo "No clean-up necessary for executable files."

# Phony targets
.PHONY: all uninstall clean