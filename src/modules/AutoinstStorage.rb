# encoding: utf-8

# File:	modules/AutoinstStorage.ycp
# Module:	Auto-Installation
# Summary:	Storage
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "y2storage"
require "y2storage/auto_inst_proposal"

module Yast
  class AutoinstStorageClass < Module

    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "RootPart"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Mode"
      Yast.import "Installation"

      # All shared data are in yast2.rpm to break cyclic dependencies
      Yast.import "AutoinstData"

      # Read existing fstab and format partitions, but dont create anything
      # Use same mountpoints etc.
      @read_fstab = false
      @ZeroNewPartitions = true

      # Fstab options
      @fstab = {}

      # Partition plan as parsed from control file
      @AutoPartPlan = []

      # Prepared target map from parsed data
      @AutoTargetMap = {}

      # default value of settings modified
      @modified = false

      @raid2device = {}

      # some architectures need a boot partition. Do we have one?
      @planHasBoot = false

      # list of devices to ignore when guessing devices
      @tabooDevices = []

      # general/storage settings
      self.general_settings = {}

      Yast.include self, "autoinstall/autopart.rb"
      Yast.include self, "autoinstall/autoinst_dialogs.rb"
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      Builtins.y2milestone("SetModified")
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Wrapper function for the LibStorage call that can't be used directly
    # in YCP
    # @return [Fixnum]
    #
    def humanStringToByte(s, b)
      s = "0b" if Builtins.size(s) == 0
      s = Ops.add(s, "b") if Builtins.findfirstof(s, "bB") == nil
# storage-ng
      log.error("FIXME : Missing storage call")
      s #Storage.ClassicStringToByte(s)
    end

    META_TYPES = [ :CT_DMRAID, :CT_MDPART, :CT_DMMULTIPATH ]
    ALL_TYPES = META_TYPES.dup.push(:CT_DISK)

    def find_next_disk( tm, after, ctype )
      Builtins.y2milestone("find_next_disk after:\"%1\" ctype:%2", after, ctype);
      used_disk = ""
      if after.empty? && !ALL_TYPES.include?(ctype)
        tm.each do |device, disk|
          if META_TYPES.include?(disk.fetch("type")) &&
             !@tabooDevices.include?(device)
            used_disk = device
          end
        end
      end

      if after.empty? && used_disk.empty?
        tm.each do |device, disk|
          if disk["bios_id"]=="0x80" && !@tabooDevices.include?(device)
            used_disk = device
          end
        end
      end

      # device guessing code enhanced
      if used_disk.empty?
        ctype = :CT_DISK  unless ALL_TYPES.include?(ctype)
        disks = tm.select { |dev,disk| disk["type"]==ctype };
        found = !disks.keys.include?(after)
        disks.each do |device, disk|
          next if !found && device != after 
          found = true if device == after
          next if device == after || @tabooDevices.include?(device)
          used_disk = device
          break
        end
      end

      Builtins.y2milestone("find_next_disk device detection: %1", used_disk)
      used_disk
    end

    # Get all the configuration from a map.
    #
    # When called by inst_auto<module name> (preparing autoinstallation data)
    # the list may be empty.
    #
    # @param  settings [Hash]        Profile settings (list of drives for custom partitioning)
    # @return	[Boolean] success
    def Import(settings)
      log.info "entering Import with #{settings.inspect}"

      # Initialize proposal if needed
      proposal =
        if settings.nil? || settings.empty?
          guided_proposal
        else
          auto_inst_proposal(settings)
        end

      begin
        proposal.propose
        log.info "Storing successful proposal"
        Y2Storage::StorageManager.instance.proposal = proposal
        true
      rescue Y2Storage::Error
        log.warn "Proposal failed"
        false
      end
    end

    # Import settings from the general/storage section
    #
    # General settings are imported with a different method because:
    #
    # * It used to happen before with the old libstorage, so we'll
    #   keep it until multipath support is implemented.
    # * To do not modify Import list of parameters (we would need
    #   to use a hash instead of a list of hashes) to retain backward
    #   compatibility.
    #
    # @param settings [Hash] general/storage section settings
    def import_general_settings(settings)
      return if settings.nil?

      self.general_settings = settings.clone

      # Backward compatibility
      if general_settings["btrfs_set_default_subvolume_name"]
        general_settings["btrfs_default_subvolume"] = general_settings.delete("btrfs_set_default_subvolume_name")
      end

      # Override product settings from control file
      Yast::ProductFeatures.SetOverlay("partitioning" => general_settings)

      # Set multipathing
      set_multipathing
    end

    # Import Fstab data
    # @param [Hash] settings Settings Map
    # @return	[Boolean] true on success
    def ImportAdvanced(settings)
      settings = deep_copy(settings)
      Builtins.y2milestone("entering ImportAdvanced with %1", settings)
      @fstab = Ops.get_map(settings, "fstab", {})
      @read_fstab = Ops.get_boolean(@fstab, "use_existing_fstab", false)
      true
    end

    # Export general settings
    #
    # @return [Hash] General settings
    def export_general_settings
      # Do not export nil settings
      general_settings.reject { |_key, value| value.nil? }
    end

    # return Summary of configuration
    # @return  [String] configuration summary dialog
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Drives"))
      num = Builtins.size(@AutoPartPlan)
      summary = Summary.AddLine(
        summary,
        Builtins.sformat(_("Total of %1 drive"), num)
      )
      summary = Summary.OpenList(summary)
      Builtins.foreach(@AutoPartPlan) do |drive|
        summary = Summary.AddListItem(
          summary,
          Ops.get_locale(drive, "device", _("No specific device configured"))
        )
      end
      summary = Summary.CloseList(summary)
      summary
    end

    # Moved here from RootPart module (used just by this module)
    def SetFormatPartitions(fstabpart)
# storage-ng
=begin
      fstabpart = deep_copy(fstabpart)
      # All storage devices
      target_map = Storage.GetTargetMap

      # all activated
      tmp = Builtins.filter(RootPart.GetActivated) do |e|
        Ops.get_string(e, :type, "") == "mount" ||
          Ops.get_string(e, :type, "") == "swap"
      end

      Builtins.foreach(tmp) do |e|
        mntpt = Ops.get_string(e, :type, "") == "swap" ?
          "swap" :
          Ops.get_string(e, :mntpt, "")
        part = Ops.get_string(e, :device, "")
        p = {}
        Builtins.foreach(fstabpart) do |pp|
          # mountpoint matches
          if Ops.get_string(pp, "mount", "") == mntpt
            p = deep_copy(pp)
            raise Break
          end
        end
        mount_options = ""
        Builtins.foreach(Storage.ReadFstab(Installation.destdir)) do |entry|
          if Ops.get_string(entry, "file", "") == mntpt
            mount_options = Ops.get_string(entry, "mntops", "")
            raise Break
          end
        end
        target_map = Storage.SetPartitionData(target_map, part, "mount", mntpt)
        target_map = Storage.SetPartitionData(
          target_map,
          part,
          "format",
          Ops.get_boolean(p, "format", false)
        )
        target_map = Storage.SetPartitionData(target_map, part, "delete", false)
        target_map = Storage.SetPartitionData(target_map, part, "create", false)
        if Builtins.haskey(p, "filesystem")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "filesystem",
            Ops.get_symbol(p, "filesystem", :ext4)
          )
        end
        if Ops.greater_than(Builtins.size(mount_options), 0) &&
            !Builtins.haskey(p, "fstopt")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "fstopt",
            mount_options
          )
        end
        if Builtins.haskey(p, "fstopt")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "fstopt",
            Ops.get_string(p, "fstopt", "")
          )
        end
        if Builtins.haskey(p, "mountby")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "mountby",
            Ops.get_symbol(p, "mountby", :device)
          )
        end
      end

      Storage.SetTargetMap(target_map)
=end
      true
    end

    # Handle /etc/fstab usage
    # @return [Boolean]
    def handle_fstab
      Builtins.y2milestone("entering handle_fstab")

      if !RootPart.didSearchForRootPartitions
        UI.OpenDialog(
          Opt(:decorated),
          Label(_("Evaluating root partition. One moment please..."))
        )
        RootPart.FindRootPartitions
        UI.CloseDialog
      end

      if RootPart.numberOfValidRootPartitions == 0
        # a popup
        Popup.Message(_("No Linux root partition found."))
        return false
      end

      # We must only change RootPart::selectedRootPartition if booting
      # is inevitable.
       rp = Ops.get_string(@fstab, "root_partition", "")
      fstab_partitions = Ops.get_list(@fstab, "partitions", [])

      if RootPart.numberOfValidRootPartitions == 1
        RootPart.SetSelectedToValid
      elsif rp == ""
        Popup.Message(
          _(
            "Multiple root partitions found, but you did not configure\nwhich root partition should be used.  Automatic installation not possible.\n"
          )
        )
        return false
      elsif Builtins.haskey(RootPart.rootPartitions, rp) &&
          Ops.greater_than(RootPart.numberOfValidRootPartitions, 1)
        RootPart.selectedRootPartition = rp
      end

      RootPart.MountPartitions(RootPart.selectedRootPartition)
      SetFormatPartitions(fstab_partitions)
      RootPart.UnmountPartitions(true)
      true
    end


    # Create partition plan
    # @return [Boolean]
    def Write
      set_multipathing
      return handle_fstab if @read_fstab
      true
    end

    # set multipathing
    # @return [void]
    def set_multipathing
      value = general_settings.fetch("start_multipath", false)
      log.info "set_multipathing to '#{value}'"
      # storage-ng
      log.error("FIXME : Missing storage call")
      #     Storage.SetMultipathStartup(val)
    end

    # Build the id for a partition entry in the man table.
    # @parm disk_dev_name name of the devie e.g.: /dev/hda
    # @parm nr number of the partition e.g.: 1
    # @return [String] e.g.: 01./dev/hda
    def build_id(disk_dev_name, nr)
      nr = deep_copy(nr)
      Builtins.sformat("%1:%2", disk_dev_name, nr)
    end

    publish :variable => :read_fstab, :type => "boolean"
    publish :variable => :ZeroNewPartitions, :type => "boolean"
    publish :variable => :fstab, :type => "map"
    publish :variable => :AutoPartPlan, :type => "list <map>"
    publish :variable => :AutoTargetMap, :type => "map <string, map>"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :planHasBoot, :type => "boolean"
    publish :variable => :tabooDevices, :type => "list <string>"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :humanStringToByte, :type => "integer (string, boolean)"
    publish :function => :find_next_disk, :type => "string (map,string,symbol)"
    publish :function => :Import, :type => "boolean (list <map>)"
    publish :function => :ImportAdvanced, :type => "boolean (map)"
    publish :function => :Summary, :type => "string ()"
    publish :function => :Write, :type => "boolean ()"

  private

    attr_accessor :general_settings

    # Initialize partition proposal
    #
    # @return [Boolean] true if proposal was successfully created; false otherwise.
    def guided_proposal
      log.info "Initializing a guided proposal"
      proposal_settings = Y2Storage::ProposalSettings.new_for_current_product
      Y2Storage::GuidedProposal.new(settings: proposal_settings)
    end

    def auto_inst_proposal(settings)
      log.info "Initializing an autoinst proposal"
      devicegraph = Y2Storage::StorageManager.instance.y2storage_probed
      disk_analyzer = Y2Storage::DiskAnalyzer.new(devicegraph)
      Y2Storage::AutoInstProposal.new(partitioning: settings, devicegraph: devicegraph, disk_analyzer: disk_analyzer)
    end
  end

  AutoinstStorage = AutoinstStorageClass.new
  AutoinstStorage.main
end
