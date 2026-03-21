#!/bin/bash

# TODO:
# udisks2 for mounting drives and USBs
# udiskie for automounting

# Vars
# You can edit these if you prefer, though it's not recommended
SOURCEDIR="$HOME/.local/src"
DOTDIR="$SOURCEDIR/dotfiles"
unset GIT_CONFIG # Fix a bug with git and paru not working together

#######################
# PRE-INSTALL SECTION #
#######################

# Enable parallel downloads
parallel_downloads() { \
    tput setaf 2; printf "Enabling parallel downloads.\n"; tput sgr0
    sudo sed -i 's/#ParallelDownloads.*/ParallelDownloads = 16/' /etc/pacman.conf # Enable parallel downloads
}
parallel_downloads && tput setaf 2; printf "Parallel downloads enabled successfully!\n"; tput sgr0

# Install 'dialog' to aid with the installation process
install_dialog() { \
	if [ -z "$(pacman -Qs dialog | grep local/dialog)" ]; then
	    tput setaf 2; printf "Installing 'dialog' to aid with the installation.\n"; tput sgr0
	    sudo pacman -S --noconfirm --needed dialog
	fi
}
install_dialog

# Define the clone dotfiles function
clone_dotfiles() { \
	tput setaf 2; printf "Cloning dotfiles repository.\n"; tput sgr0
	mkdir -p "$SOURCEDIR"
	git clone https://github.com/naordl/dotfiles.git "$DOTDIR"
}

# Confirm installation
confirm_install() { \
	dialog --title "DISCLAIMER" --yesno "This script deletes and moves certain configuration files.\n\nAre you sure you wish to proceed with the installation?" 8 80
	answer=$?
	clear
	case $answer in
	   0) clear && clone_dotfiles;; # Clone dotfiles if user agrees to installation
	   1) clear && tput setaf 1; printf "Installation aborted by user.\n"; tput sgr0 && exit 1;;
	   255) clear && tput setaf 1; printf "Installation aborted by user.\n"; tput sgr0 && exit 1;;
	esac
}
confirm_install

# Exit if $SOURCEDIR does not exist
check_sourcedir() { \
	if [ ! -d "$SOURCEDIR" ]; then
	    dialog --title "ERROR" --msgbox "'"$SOURCEDIR"' directory does not exist.\n\nPlease create it and place the 'dotfiles' directory inside.\n" 7 60
	    clear
	    tput setaf 1; printf "Installation aborted.\n"; tput sgr0
	    exit 1
	fi
}
check_sourcedir

# Exit if $DOTDIR does not exist
check_dotdir() { \
	if [ ! -d "$DOTDIR" ]; then
	    dialog --title "ERROR" --msgbox "'"$DOTDIR"' directory does not exist.\n\nPlease place the 'dotfiles' directory inside of '"$SOURCEDIR"'.\n" 7 90
	    clear
	    tput setaf 1; printf "Installation aborted.\n"; tput sgr0
	    exit 1
	fi
}
check_dotdir


###################
# INSTALL SECTION #
###################

# Update mirrors for faster download speeds
# You might want to change the argument for the country
update_mirrors() { \
	tput setaf 2; printf "Updating pacman mirrorlist.\n"; tput sgr0
	sudo pacman -S reflector --noconfirm --needed
	sudo reflector --verbose -c Romania -a 12 -p https --sort rate --save /etc/pacman.d/mirrorlist
}
update_mirrors && tput setaf 2; printf "Pacman mirrorlist updated successfully!\n"; tput sgr0

# Run full system update
full_system_update() { \
	tput setaf 2; printf "Running full system update.\n"; tput sgr0
	sudo pacman -Syu --noconfirm
}
full_system_update && tput setaf 2; printf "System updated successfully!\n"; tput sgr0

# Install 'base-devel' package group
install_base-devel() { \
	if [ -z "$(pacman -Qs base-devel | grep local/base-devel)" ]; then
		tput setaf 2; printf "Installing 'base-devel' group.\n"; tput sgr0
		sudo pacman -S --noconfirm --needed base-devel
	fi
}
install_base-devel && tput setaf 2; printf "'base-devel' installed successfully!\n"; tput sgr0

# Install 'linux-firmware' package group
install_linux-firmware() { \
	if [ -z "$(pacman -Qs linux-firmware | grep local/linux-firmware)" ]; then
		tput setaf 2; printf "Installing 'linux-firmware' group.\n"; tput sgr0
		sudo pacman -S --noconfirm --needed linux-firmware
	fi
}
install_linux-firmware && tput setaf 2; printf "'linux-firmware' installed successfully!\n"; tput sgr0

# Install 'paru' AUR helper
install_paru() { \
	if [ -z "$(pacman -Qs paru | grep local/paru)" ]; then
		tput setaf 2; printf "Installing 'paru' AUR helper.\n"; tput sgr0
		sudo pacman -S --noconfirm --needed git && git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin && cd /tmp/paru-bin && makepkg -si --noconfirm && cd
	fi
}
install_paru && tput setaf 2; printf "'paru' installed successfully!\n"; tput sgr0


# Ask user for GPU drivers
install_gpu_drivers() { \
	cmd=(dialog --separate-output --checklist "Select GPU driver(s) to install:" 22 76 16)
	options=(1 "xf86-video-intel" off
	         2 "xf86-video-amdgpu" off
	         3 "xf86-video-ati" off
	         4 "xf86-video-nouveau" off
	         5 "nvidia nvidia-settings nvidia-utils" off
	         6 "xf86-video-vmware" off
	         7 "xf86-video-qxl" off)
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	clear
	for choice in $choices
	do
	    case $choice in
	        1)
	            gpu="$gpu xf86-video-intel"
	            ;;
	        2)
	            gpu="$gpu xf86-video-amdgpu"
	            ;;
	        3)
	            gpu="$gpu xf86-video-ati"
	            ;;
	        4)
	            gpu="$gpu xf86-video-nouveau"
	            ;;
	        5)
	            gpu="$gpu nvidia nvidia-settings nvidia-utils"
	            ;;
	        6)
	            gpu="$gpu xf86-video-vmware"
	            ;;
	        7)
	            gpu="$gpu xf86-video-qxl"
	            ;;
	    esac
	done
	clear
	if [ -n "$gpu" ]; then
		tput setaf 2; printf "Installing GPU driver(s).\n"; tput sgr0
		paru -S --needed --noconfirm --skipreview --noremovemake $gpu && tput setaf 2; printf "GPU driver(s) installed successfully!\n"; tput sgr0
	fi
}
install_gpu_drivers

# Check if the environment is a Virtual Machine
# If yes, ask user for VirtualBox Guest Utils
check_vm() { \
	if [ -n "$(grep ^flags.*\ hypervisor /proc/cpuinfo)" ]; then
		install_vmutils() { \
			paru -S --noconfirm --needed virtualbox-guest-utils
			sudo systemctl enable vboxservice
		}
		dialog --title "VIRTUAL MACHINE DETECTED" --yesno "Install 'virtualbox-guest-utils'?" 8 80
		answer=$?
		clear
		case $answer in
		   0) clear && install_vmutils && tput setaf 2; printf "Virtualbox Guest Utils installed successfully!\n"; tput sgr0;;
		   1) clear;;
		   255) clear && tput setaf 1; printf "Installation aborted by user.\n"; tput sgr0 && exit 1;;
		esac
	fi
}
check_vm

# Check if hte environment is a laptop
# If yes, ask user for laptop components
check_laptop() { \
	if [ -d "/sys/module/battery" ]; then # Check for a battery
		cmd=(dialog --separate-output --checklist "Select laptop-specific components to install:" 22 76 16)
		options=(1 "libinput (Touchpad driver)" on
			 2 "tlp powertop (Battery tools)" on
			 3 "bluez bluez-utils (Bluetooth tools)" on
			 4 "bcm43142a0-firmware (Broadcom Bluetooth driver)" off
			 5 "acpilight (Screen brightness tool)" on
			 6 "broadcom-wl (Broadcom wireless driver)" off)
		choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
		clear
		for choice in $choices
		do
		    case $choice in
		        1)
			    laptopcomponents="$laptopcomponents libinput"
		            ;;
		        2)
		            laptopcomponents="$laptopcomponents tlp powertop"
		            ;;
		        3)
		            laptopcomponents="$laptopcomponents bluez bluez-utils"
		            ;;
		        4)
		            laptopcomponents="$laptopcomponents bcm43142a0-firmware"
		            ;;
		        5)
		            laptopcomponents="$laptopcomponents acpilight"
		            ;;
		        6)
		            laptopcomponents="$laptopcomponents broadcom-wl"
		            ;;
		    esac
		done

	fi
	if [ -n "$laptopcomponents" ]; then
		tput setaf 2; printf "Installing laptop components.\n"; tput sgr0
		paru -S --needed --noconfirm --skipreview --noremovemake $laptopcomponents && tput setaf 2; printf "Laptop components installed successfully!\n"; tput sgr0
	fi
}
check_laptop

# Install essential packages
install_essentials() { \
	displayserver="xorg-server xorg-xinit"
	audio="pulseaudio pulseaudio-alsa pulseaudio-bluetooth"
	fonts="ttf-dejavu ttf-dejavu-nerd terminus-font"
	essentials="
	    $displayserver
	    $audio
	    $fonts
	    "
	if [ -n "$essentials" ]; then
		tput setaf 2; printf "Installing essential components.\n"; tput sgr0
		paru -S --needed --noconfirm --skipreview --noremovemake $essentials
	fi
}
install_essentials && tput setaf 2; printf "Essential components installed successfully!\n"; tput sgr0

# Install packages for aestethics
install_aestethics() { \
	iconfonts="ttf-font-awesome"
	emojifonts="ttf-joypixels"
	icontheme="papirus-icon-theme"
	gtktheme="arc-gtk-theme lxappearance" # + Clone themes from github

	aestethics="
	    $iconfonts
	    $emojifonts
	    $icontheme
	    $gtktheme
	    "
	if [ -n "$aestethics" ]; then
		tput setaf 2; printf "Installing aestethic components.\n"; tput sgr0
		paru -S --needed --noconfirm --skipreview --noremovemake $aestethics
	fi

	# Install my theme collection
	tput setaf 2; printf "Installing themes.\n"; tput sgr0
	git clone https://github.com/demo2k20/themes.git $SOURCEDIR/themes
	sudo ln -srv $SOURCEDIR/themes/* /usr/share/themes
}
install_aestethics && tput setaf 2; printf "Aestethic components installed successfully!\n"; tput sgr0

# Install software
install_software() { \
	shell="zsh zsh-syntax-highlighting dash dashbinsh" # AUR
	#terminal="alacritty" # Cloning st build instead from my GitHub
	#launcher="dmenu" # Cloning dmenu build instead from my GitHub
	notifications="libnotify dunst"
	browser="firefox"
	torrent="transmission-cli"
	calculator="bc"
	calendar="calcurse"
	compositor="xcompmgr"
	taskmanager="htop"
	audiomixer="pulsemixer pavucontrol"
	filemanager="ranger ueberzugpp dragon-drop" # AUR
	mediaplayer="mpv"
	videoconverter="handbrake"
	musicplayer="mpd ncmpcpp mpc"
	imageviewer="sxiv"
	imageeditor="gimp inkscape"
	webcammanager="guvcview"
	displaysettings="xorg-xrandr arandr"
	nightlight="xsct" # AUR
	printscreen="maim"
	ssh="openssh"
	pdfviewer="zathura zathura-pdf-poppler"
	unclutter="unclutter"
	locate="mlocate"
	manuals="man-db man-pages"
	documents="libreoffice-fresh hunspell-en_us hunspell-hu hunspell-ro texlive-basic pandoc" # AUR
	spreadsheets="libxlsxwriter sc-im-git" # AUR
	ocr="tesseract tesseract-data-eng tesseract-data-hun tesseract-data-ron" # AUR
	fstools="dosfstools mtools simple-mtpfs ntfs-3g" # AUR
	compressiontools="rar zip unzip p7zip bzip2 gzip xz"
	java="liberica-jdk-8-full-bin" # AUR

	software="
	    $shell
	    $terminal
	    $launcher
	    $notifications
	    $browser
	    $torrent
	    $calculator
	    $calendar
	    $compositor
	    $taskmanager
	    $audiomixer
	    $filemanager
	    $mediaplayer
	    $videoconverter
	    $imageviewer
	    $imageeditor
	    $webcammanager
	    $displaysettings
	    $nightlight
	    $printscreen
	    $ssh
	    $pdfviewer
	    $unclutter
	    $locate
	    $manuals
	    $documents
	    $spreadsheets
	    $ocr
	    $fstools
	    $compressiontools
	    "
	if [ -n "$software" ]; then
		tput setaf 2; printf "Installing software.\n"; tput sgr0
		paru -S --needed --noconfirm --skipreview --noremovemake $software
	fi

	# Install my dmenu build
	tput setaf 2; printf "Installing dmenu.\n"; tput sgr0
	git clone https://github.com/demo2k20/dmenu.git $SOURCEDIR/dmenu
	cd $SOURCEDIR/dmenu && sudo make clean install && cd

	# Install my st build
	tput setaf 2; printf "Installing st.\n"; tput sgr0
	git clone https://github.com/demo2k20/st.git $SOURCEDIR/st
	cd $SOURCEDIR/st && sudo make clean install && cd

	# Install my dwm build
	tput setaf 2; printf "Installing dwm.\n"; tput sgr0
	git clone https://github.com/demo2k20/dwm.git $SOURCEDIR/dwm
	cd $SOURCEDIR/dwm && sudo make clean install && cd

	# Install my dwmblocks build
	tput setaf 2; printf "Installing dwmblocks.\n"; tput sgr0
	git clone https://github.com/demo2k20/dwmblocks.git $SOURCEDIR/dwmblocks
	cd $SOURCEDIR/dwmblocks && sudo make clean install && cd
}
install_software && tput setaf 2; printf "Software installed successfully!\n"; tput sgr0

# Install my shell script dependencies
install_dependencies() { \
	dependencies="
	    python-pynvim
	    lm_sensors
	    xss-lock
	    xorg-xset
	    xdotool
	    xclip
	    exa
	    playerctl
	    imagemagick
	    xwallpaper
	    wmctrl
	    rsync
	    i3lock
	    yt-dlp
	    pamixer
	    xorg-xrdb
	    acpi_call
	    fzf
	    cronie
	    xorg-xinput
	    xdg-user-dirs
	    "
	if [ -n "$software" ]; then
		tput setaf 2; printf "Installing dependencies.\n"; tput sgr0
		paru -Syu --needed --noconfirm --skipreview --noremovemake $dependencies
	fi
	}
install_dependencies && tput setaf 2; printf "Dependencies installed successfully!\n"; tput sgr0

##################
# DEPLOY SECTION #
##################

# Deploy dotfiles
deploy_dotfiles() { \
    tput setaf 2; printf "Deploying dotfiles.\n"; tput sgr0
    ln -sfrv $DOTDIR/.config/* $HOME/.config/
    ln -sfrv $DOTDIR/.local/* $HOME/.local/
    ln -sfv $DOTDIR/.zprofile $HOME/.zprofile
    sudo cp -rv $DOTDIR/etc/* /etc/
}
deploy_dotfiles && tput setaf 2; printf "Deployed dotfiles successfully!\n"; tput sgr0

#########################
# CONFIGURATION SECTION #
#########################

# Shell
configure_shell() { \
    tput setaf 2; printf "Setting up zsh and dash.\n"; tput sgr0
    sudo ln -sfTv dash /usr/bin/sh
    sudo chsh -s /bin/zsh root
    sudo chsh -s /bin/zsh $USER
    sudo ln -sfv $DOTDIR/.config/zsh/.zshrc /root/.zshrc
}
configure_shell && tput setaf 2; printf "Shell configured successfully!\n"; tput sgr0

# Crontab
configure_cronie() { \
    tput setaf 2; printf "Setting up cronie.\n"; tput sgr0
    crontab $DOTDIR/.config/crontab.save.dinh
    sudo crontab $DOTDIR/.config/root-crontab.save.dinh
}
configure_cronie && tput setaf 2; printf "Cronie configured successfully!\n"; tput sgr0

# Create the Nvidia GPU disabler service
#sudo cp -rv /etc/systemd/system/disablenvidia.service /lib/systemd/system/
#sudo chmod 644 /etc/systemd/system/disablenvidia.service

# Systemd services
configure_systemd() { \
    tput setaf 2; printf "Enabling systemd services.\n"; tput sgr0
    #sudo systemctl enable disablenvidia # TODO: move this to a separate function, ask the user with 'dialog' if they want it
    #sudo systemctl enable sshd # For servers
    sudo systemctl enable cronie
    sudo systemctl enable getty@tty1
    sudo systemctl enable bluetooth
    sudo systemctl enable tlp
    sudo systemctl enable fstrim.timer # Only use this if you installed Arch to an SSD
    sudo systemctl enable reflector.service
}
configure_systemd && tput setaf 2; printf "Systemd services configured successfully!\n"; tput sgr0

# Grub and mkinitcpio
configure_boot() { \
    tput setaf 2; printf "Rebuilding GRUB and kernel modules.\n"; tput sgr0
    sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0' /etc/default/grub # Change grub wait time to 0 seconds
    sudo sed -i 's/ quiet//' /etc/default/grub # Remove quiet boot
    partition=$(df | grep -w / | awk '{ print $1 }')
    sudo sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"resume=$partition\"|" /etc/default/grub # Add hibernation partition
    sudo grub-mkconfig -o /boot/grub/grub.cfg # Rebuild grub to apply changes
    sudo mkinitcpio -P # Currently not making any changes to mkinitcpio.conf; but TODO: make a sed command to separately and directly edit the mkinitcpio.conf file instead of having to copy something else over it and to make the necessary changes
}
configure_boot && tput setaf 2; printf "Boot configured successfully!\n"; tput sgr0

# Makepkg
configure_makepkg() { \
    tput setaf 2; printf "Configuring MAKEPKG.\n"; tput sgr0
    sudo sed -i "s/#MAKEFLAGS.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf # Allocate the number of cores the CPU has to makepkg; that way packages from the AUR are built way faster
}
configure_makepkg && tput setaf 2; printf "MAKEPKG configured successfully!\n"; tput sgr0

# Pacman package manager
configure_pacman() { \
    tput setaf 2; printf "Configuring Pacman.\n"; tput sgr0
    sudo sed -i 's/#Color/Color/' /etc/pacman.conf # Enable color
    sudo sed -i 's/#ParallelDownloads.*/ParallelDownloads = 16/' /etc/pacman.conf # Enable parallel downloads persistently

}
configure_pacman && tput setaf 2; printf "Pacman configured successfully!\n"; tput sgr0

# Keyboard layout
configure_layout() { \
    tput setaf 2; printf "Configuring keyboard layout.\n"; tput sgr0
    sudo localectl --no-convert set-x11-keymap hu,ro,en "" "" grp:win_space_toggle,caps:swapescape # Enables Hungarian, Romanian, and English layouts, Win + Space toggles between layotus, and swaps Capslock with Escape
}
configure_layout && tput setaf 2; printf "Keyboard layout configured successfully!\n"; tput sgr0
# TODO: ask the user for keyboard layouts and run the command based on user input

# Done
tput setaf 2; printf "Configuration successful!\n"; tput sgr0

###################
# CLEANUP SECTION #
###################

run_cleanup() { \
    tput setaf 2; printf "Cleaning up '$HOME'.\n"; tput sgr0
    rm -rfv $HOME/.bashrc
    rm -rfv $HOME/.bash_profile
    rm -rfv $HOME/.bash_history
    rm -rfv $HOME/.bash_logout
    rm -rfv $HOME/.bash_login
    rm -rfv $HOME/.pki/
    rm -rfv $HOME/.icons/
    rm -rfv $HOME/.Xauthority
    rm -rfv $HOME/.xinitrc
}
run_cleanup && tput setaf 2; printf "Cleanup successful!\n"; tput sgr0

########################
# POST-INSTALL SECTION #
########################

# Ask the user if they want user directories
create_user_dirs() { \
	tput setaf 2; printf "Creating user directories.\n"; tput sgr0
	mkdir -pv $HOME/{'Documents','Music','Pictures','Videos','.local','.config'}
	xdg-user-dirs-update
	}
dialog --yesno "Would you like to create user directories (Documents, Music, Pictures, Videos)? (Recommended)" 8 80
answer=$?
clear
case $answer in
   0) clear && create_user_dirs && tput setaf 2; printf "User directories created successfully!\n"; tput sgr0;;
   1) clear && printf "User directories were not created.\n";;
   255) clear && tput setaf 1; printf "User directories were not created.\n"; tput sgr0;;
esac

# Done
tput setaf 2; printf "\nSuccessfully finished installing packages, deploying dotfiles, and configuring the system.\n\nReboot with the command 'reboot' for the changes to take effect.\n"; tput sgr0
