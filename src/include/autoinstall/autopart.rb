# encoding: utf-8

# File:	include/autoinstall/autpart.rb
# Module:	Auto-Installation
# Summary:	Storage
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallAutopartInclude
    def initialize_autoinstall_autopart(include_target)
      textdomain "autoinst"

      Yast.import "Arch"

      @cur_mode = :free
      @cur_weight = -10000
      @cur_gap = {}
    end

    # Build a subvolume specification from the current definition
    #
    # The result is suitable to be used to generate an AutoYaST profile.
    #
    # @param subvolume [Hash] Subvolume definition (internal storage layer definition)
    # @param prefix    [String] Subvolume prefix (usually default subvolume + '/')
    # @return [Hash] External representation of a subvolume (e.g. to be used by AutoYaST)
    def export_subvolume(subvolume, prefix = "")
      spec = {
        "path" => subvolume["name"].sub(/\A#{prefix}/, "")
      }
      spec["copy_on_write"] = !subvolume["nocow"]
      spec
    end

    def AddFilesysData(st_map, xml_map)
      st_map = deep_copy(st_map)
      xml_map = deep_copy(xml_map)
      ret = AddSubvolData(st_map, xml_map)
      if Ops.get_boolean(ret, "format", false) &&
          !Builtins.isempty(Ops.get_string(xml_map, "mkfs_options", ""))
        Ops.set(
          ret,
          "mkfs_options",
          Ops.get_string(xml_map, "mkfs_options", "")
        )
        Builtins.y2milestone(
          "AddFilesysData mkfs_options:%1",
          Ops.get_string(ret, "mkfs_options", "")
        )
      end
      deep_copy(ret)
    end
  end
end
