# encoding: utf-8

# File:	clients/autoyast.ycp
# Summary:	Main file for client call
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallConftreeInclude
    def initialize_autoinstall_conftree(include_target)
      textdomain "autoinst"
      Yast.import "HTML"
      Yast.import "XML"
      Yast.import "Call"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Report"
      Yast.import "AutoinstConfig"
      Yast.import "Profile"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Icon"
      Yast.import "AutoinstSoftware"
      Yast.import "AutoinstClone"

      @title = _("Autoinstallation - Configuration")
      @show_source = false
    end

    def SaveAs
      filename = UI.AskForSaveFileName(
        AutoinstConfig.Repository,
        "*",
        _("Save as...")
      )
      if filename != nil && Convert.to_string(filename) != ""
        AutoinstConfig.currentFile = Convert.to_string(filename)
        if Profile.Save(AutoinstConfig.currentFile)
          Popup.Message(
            Builtins.sformat(
              _("File %1 was saved successfully."),
              AutoinstConfig.currentFile
            )
          )
          #                Profile::checkProfile();
          Profile.changed = false
          pathComponents = Builtins.splitstring(
            Convert.to_string(filename),
            "/"
          )
          s = Ops.subtract(Builtins.size(pathComponents), 1)
          base = Ops.get_string(pathComponents, s, "default")
        else
          Popup.Warning(_("An error occurred while saving the file."))
        end
      end
      :next
    end

    # Creates the group selection box with the specified YaST group selected.
    #
    # @param [String] selectedGroup The group to select.
    # @return The newly created `SelectionBox widget.
    def groups(selectedGroup)
      itemList = []
      sortedGroups = Builtins.maplist(Y2ModuleConfig.GroupMap) { |k, v| k } # keys()
      sortedGroups = Builtins.sort(sortedGroups) do |a, b|
        aa = Builtins.tointeger(
          Ops.get_string(Y2ModuleConfig.GroupMap, [a, "SortKey"], "500")
        )
        bb = Builtins.tointeger(
          Ops.get_string(Y2ModuleConfig.GroupMap, [b, "SortKey"], "500")
        )
        aa != bb ? Ops.less_than(aa, bb) : Ops.less_than(a, b) # by "SortKey" or alphabetical
      end

      Builtins.foreach(sortedGroups) do |k|
        v = Ops.get(Y2ModuleConfig.GroupMap, k, {})
        desktop_file = Builtins.substring(
          Ops.get_string(v, "X-SuSE-DocTeamID", ""),
          4
        )
        translation = Builtins.dpgettext(
          "desktop_translations",
          "/usr/share/locale/",
          Ops.add(
            Ops.add(Ops.add("Name(", desktop_file), ".desktop): "),
            Ops.get_string(v, "Name", "")
          )
        )
        if translation ==
            Ops.add(
              Ops.add(Ops.add("Name(", desktop_file), ".desktop): "),
              Ops.get_string(v, "Name", "")
            )
          translation = Ops.get_string(v, "Name", "")
        end
        item = Item(
          Id(k),
          term(:icon, Ops.get_string(v, "Icon", "")),
          translation,
          k == selectedGroup
        )
        itemList = Builtins.add(itemList, item)
      end
      SelectionBox(Id(:groups), Opt(:notify), _("Groups"), itemList)
    end

    # Creates the modules selection box displaying modules in the specified group.
    # The specified YaST module is selected.
    #
    # @param [String] group_name YaST group of modules to display.
    # @param [String] selectedModule Module to preselect.
    def modules(group_name, selectedModule)
      Builtins.y2milestone("group_name: %1", group_name)
      itemList = []
      Builtins.foreach(Y2ModuleConfig.ModuleMap) do |k, v|
        # bnc #887115 comment #9: Desktop file is "hidden" and should not be shown at all
        next if v["Hidden"] == "true"

        if Ops.get_string(v, "X-SuSE-YaST-Group", "") == group_name
          desktop_file = Builtins.substring(
            Ops.get_string(v, "X-SuSE-DocTeamID", ""),
            4
          )
          translation = Builtins.dpgettext(
            "desktop_translations",
            "/usr/share/locale/",
            Ops.add(
              Ops.add(Ops.add("Name(", desktop_file), ".desktop): "),
              Ops.get_string(v, "Name", "")
            )
          )
          if translation ==
              Ops.add(
                Ops.add(Ops.add("Name(", desktop_file), ".desktop): "),
                Ops.get_string(v, "Name", "")
              )
            translation = Ops.get_string(v, "Name", "")
          end
          item = Item(
            Id(k),
            term(:icon, Ops.get_string(v, "Icon", "")),
            translation,
            k == selectedModule
          )
          itemList = Builtins.add(itemList, item)
        end
      end
      if 0 == Builtins.size(itemList)
        itemList = Builtins.add(
          itemList,
          Item(Id("none"), _("No modules available"))
        )
      end
      SelectionBox(Id(:modules), Opt(:notify), _("Modules"), itemList)
    end

    # Creates an `HBox containing the buttons to be displayed below the summary column
    #
    # @return The `HBox widget.
    def buttons
      Wizard.HideNextButton
      Wizard.HideBackButton
      Wizard.HideAbortButton
      HBox(
        HSpacing(1),
        VBox(
          PushButton(Id(:read), _("&Clone")),
          PushButton(Id(:writeNow), _("&Apply to System"))
        ),
        HStretch(),
        VBox(
          PushButton(Id(:configure), _("&Edit")),
          PushButton(Id(:reset), _("Clea&r"))
        ),
        HSpacing(1)
      )
    end

    # Creates a `VBox containg the summary of the specified module and the action buttons below.
    #
    # @param [String] module_name The module to summarize.
    # @return The `VBox widget.
    def details(module_name)
      resourceMap = Ops.get(Y2ModuleConfig.ModuleMap, module_name, {})
      module_auto = Ops.get_string(
        resourceMap,
        "X-SuSE-YaST-AutoInstClient",
        "none"
      )
      summary = Convert.to_string(WFM.CallFunction(module_auto, ["Summary"]))
      summary = "" if nil == summary
      VBox(Left(Label(_("Details"))), RichText(summary), buttons)
    end

    # Sets the high level layout to 3 columns:
    #
    #	- left:	  the YaST groups are displayed in a selection box
    #	- middle: the modules of the selected group are displayed in a selection box
    #	- right:  the summary of the selected module is displayed, action buttons below
    #
    # @param [String] preselectedGroup The YaST group to preselect
    # @param [String] preselectedModule The module to preselect
    def layout(preselectedGroup, preselectedModule)
      HBox(
        HWeight(33, groups(preselectedGroup)),
        HWeight(
          33,
          ReplacePoint(
            Id(:rp_modules),
            modules(preselectedGroup, preselectedModule)
          )
        ),
        HWeight(33, ReplacePoint(Id(:rp_details), details(preselectedModule)))
      )
    end

    # Set the group selection box to the specified YaST group.
    #
    # @param group_name YaST group to select.
    def setGroup(group_name)
      UI.ChangeWidget(Id(:groups), :CurrentItem, group_name)
      updateModules

      nil
    end

    # Get the currently selected YaST group from the selection box widget.
    #
    # @return The currently selected group.
    def getGroup
      Convert.to_string(UI.QueryWidget(Id(:groups), :CurrentItem))
    end

    # Get the currently selected Module from the selection box widget.
    #
    # @return The currently selected module.
    def getModule
      Convert.to_string(UI.QueryWidget(Id(:modules), :CurrentItem))
    end

    ALWAYS_CLONABLE_MODULES = ["software", "partitioning", "bootloader"]

    # Updates the action button activation status. (Some modules are not
    # clonable, some are not writeable).
    #
    # @param [String] selectedModule The module to define the button status.
    def updateButtons(selectedModule)
      # enable/disable write button
      if Builtins.contains(AutoinstConfig.noWriteNow, selectedModule)
        UI.ChangeWidget(Id(:writeNow), :Enabled, false)
      end

      # set read button status
      resourceMap = Y2ModuleConfig.ModuleMap.fetch(selectedModule, {})
      clonable = resourceMap["X-SuSE-YaST-AutoInstClonable"] == "true"

      clone_button_status = clonable || ALWAYS_CLONABLE_MODULES.include?(selectedModule)
      UI.ChangeWidget(Id(:read), :Enabled, clone_button_status)

      nil
    end

    # Set the module selection box to the specified YaST module and
    # update the details and group column.
    #
    # @param [String] module_name The module to select.
    def setModule(module_name)
      resourceMap = Ops.get(Y2ModuleConfig.ModuleMap, module_name, {})
      if {} != resourceMap
        group = Ops.get_string(resourceMap, "X-SuSE-YaST-Group", "")
        setGroup(group) if "" != group
        UI.ChangeWidget(Id(:modules), :CurrentItem, module_name)
        updateDetails
      end

      nil
    end
    def updateModules
      selectedGroup = getGroup
      Builtins.y2milestone("group: %1", selectedGroup)
      newModules = modules(selectedGroup, "")
      UI.ReplaceWidget(Id(:rp_modules), newModules)
      updateDetails

      nil
    end
    def updateDetails
      selectedModule = Convert.to_string(
        UI.QueryWidget(Id(:modules), :CurrentItem)
      )
      Builtins.y2milestone("module: %1", selectedModule)
      newDetails = details(selectedModule)
      UI.ReplaceWidget(Id(:rp_details), newDetails)
      updateButtons(selectedModule)

      nil
    end

    # Reset Configuration
    # @param [String] resource Module/Resource to reset
    # @return [Object]
    def resetModule(resource)
      Builtins.y2debug("resource: %1", resource)
      resourceMap = Ops.get(Y2ModuleConfig.ModuleMap, resource, {})
      module_auto = Ops.get_string(
        resourceMap,
        "X-SuSE-YaST-AutoInstClient",
        "none"
      )
      if Builtins.haskey(Profile.current, resource)
        Profile.current = Builtins.remove(Profile.current, resource)
      end
      profile_resource = Y2ModuleConfig.getResource(resource)
      WFM.CallFunction(module_auto, ["Reset"])

      :next
    end

    # Read the setting of the specifed module from the current system.
    #
    # @param [String] module_name The module to read in.
    def readModule(module_name)
      resourceMap = Ops.get(Y2ModuleConfig.ModuleMap, module_name, {})
      auto = Ops.get_string(resourceMap, "X-SuSE-YaST-AutoInstClient", "")
      Call.Function(auto, ["Read"])
      Call.Function(auto, ["SetModified"])
      Profile.prepare = true
      Profile.changed = true
      true
    end
    # Configure module
    # @param [String] resource Module/Resource to configure
    # @return [Object]
    def configureModule(resource)
      resourceMap = Ops.get(Y2ModuleConfig.ModuleMap, resource, {})
      resource = Y2ModuleConfig.getResource(resource)
      Builtins.y2debug("resource: %1", resource)

      module_auto = Ops.get_string(
        resourceMap,
        "X-SuSE-YaST-AutoInstClient",
        "none"
      )
      Builtins.y2debug("module_auto: %1", module_auto)

      Builtins.y2milestone("Mode::mode %1", Mode.mode)
      original_settings = WFM.CallFunction(module_auto, ["Export"])
      seq = WFM.CallFunction(module_auto, ["Change"])
      Builtins.y2milestone("Change response: %1", seq)
      if seq == :accept || seq == :next || seq == :finish
        new_settings = WFM.CallFunction(module_auto, ["Export"])
        if new_settings == nil
          Builtins.y2milestone("Importing original settings.")
          Popup.Error(_("The module returned invalid data."))
          WFM.CallFunction(module_auto, ["Import", original_settings])
          return :abort
        else
          Builtins.y2milestone("original=%1", original_settings)
          Builtins.y2milestone("new=%1", new_settings)
          if original_settings != new_settings
            WFM.CallFunction(module_auto, ["SetModified"])
            Profile.changed = true
            Profile.prepare = true
          end
        end
      else
        WFM.CallFunction(module_auto, ["Import", original_settings])
      end
      deep_copy(seq)
    end


    # Sets the menus in the wizard.
    # @return [void]
    def menus
      _Menu = []
      _Menu = Wizard.AddMenu(_Menu, _("&File"), "file-menu")
      _Menu = Wizard.AddMenu(_Menu, _("&View"), "view-menu")
      _Menu = Wizard.AddMenu(_Menu, _("&Classes"), "class-menu")
      _Menu = Wizard.AddMenu(_Menu, _("&Tools"), "tools-menu")

      _Menu = Wizard.AddMenuEntry(_Menu, "file-menu", _("&New"), "menu_new")
      _Menu = Wizard.AddMenuEntry(_Menu, "file-menu", _("&Open"), "menu_open")
      _Menu = Wizard.AddMenuEntry(_Menu, "file-menu", _("&Save"), "menu_save")
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "file-menu",
        _("Save &As"),
        "menu_saveas"
      )
      _Menu = Wizard.AddSubMenu(_Menu, "file-menu", _("Im&port"), "file-import")
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "file-import",
        _("Import &Kickstart File"),
        "menu_kickstart"
      )
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "file-menu",
        _("Settin&gs"),
        "menu_settings"
      )
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "file-menu",
        AutoinstConfig.ProfileEncrypted ?
          _("Change to Decrypted") :
          _("Change to Encrypted"),
        "change_encryption"
      )
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "file-menu",
        _("Apply Profile to this System"),
        "write_to_system"
      )
      _Menu = Wizard.AddMenuEntry(_Menu, "file-menu", _("E&xit"), "menu_exit")
      if @show_source == true
        _Menu = Wizard.AddMenuEntry(
          _Menu,
          "view-menu",
          _("Configu&ration Tree"),
          "menu_tree"
        )
      else
        _Menu = Wizard.AddMenuEntry(
          _Menu,
          "view-menu",
          _("So&urce"),
          "menu_source"
        )
      end
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "class-menu",
        _("Cla&sses"),
        "menu_classes"
      )
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "class-menu",
        _("Me&rge Classes"),
        "menu_merge"
      )

      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "tools-menu",
        _("Create Reference Pro&file"),
        "menu_clone"
      )
      _Menu = Wizard.AddMenuEntry(
        _Menu,
        "tools-menu",
        _("Check &Validity of Profile"),
        "menu_valid"
      )
      Wizard.CreateMenu(_Menu)
      nil
    end

    # Create the complete dialog (called in wizard.ycp and in MainDialog())
    # @param [String] currentGroup Group to select.
    # @param [String] currentModule Module to select.
    # @return [void]
    def CreateDialog(currentGroup, currentModule)
      currentGroup = "System" if "" == currentGroup || nil == currentGroup
      currentModule = "general" if "" == currentModule || nil == currentModule
      Wizard.SetContents(
        @title,
        layout(currentGroup, currentModule),
        AutoinstConfig.MainHelp,
        true,
        true
      )
      updateButtons(currentModule)
      nil
    end




    # Show Source
    def ShowSource
      Profile.Prepare
      source = XML.YCPToXMLString(:profile, Profile.current)
      sourceView = RichText(Id(:class_source), Opt(:plainText), source)

      Wizard.SetTitleIcon("autoyast")
      Wizard.SetContents(
        _("Source"),
        sourceView,
        AutoinstConfig.MainHelp,
        true,
        true
      )
      nil
    end

    # Menu interface
    # @param list menu items
    # @return [Symbol]
    def MainDialog
      _Icons = {}
      Ops.set(_Icons, "Net_advanced", "network_advanced")
      func_ret = ""
      ret = nil
      currentGroup = "System"
      currentModule = "general"

      while true
        if AutoinstConfig.runModule != ""
          ret = :configure
          setModule(AutoinstConfig.runModule)
          AutoinstConfig.runModule = ""
        else
          event = UI.WaitForEvent
          ret = Ops.get(event, "ID")
          AutoinstConfig.runModule = ""
        end
        if ret == :groups
          updateModules
        elsif ret == :modules
          updateDetails
        elsif ret == :configure
          currentGroup = getGroup
          currentModule = getModule
          Builtins.y2debug("configure module: %1", currentModule)
          if currentModule != ""
            configret = configureModule(currentModule)
            Builtins.y2debug("configureModule ret : %1", configret)
            # Some configuration modules removes/exchange the menu bar.
            # So we have to reset. (bnc#872711)
            Wizard.DeleteMenus
            menus
            CreateDialog(currentGroup, currentModule)
          end
        elsif ret == :reset
          Profile.prepare = true
          Builtins.y2debug("reset")
          currentGroup = getGroup
          currentModule = getModule
          Builtins.y2debug("reset module: %1", currentModule)
          if currentModule != ""
            configret = resetModule(currentModule)
            Builtins.y2debug("resetModule ret : %1", configret)
            CreateDialog(currentGroup, currentModule)
          end
        elsif ret == :writeNow
          modulename = getModule
          if modulename != ""
            d = Ops.get(Y2ModuleConfig.ModuleMap, modulename, {})
            module_auto = ""
            if Builtins.haskey(d, "X-SuSE-YaST-AutoInstClient")
              module_auto = Ops.get_string(
                d,
                "X-SuSE-YaST-AutoInstClient",
                "none"
              )
            else
              module_auto = Builtins.sformat("%1_auto", modulename)
            end
            if Popup.YesNo(
                Builtins.sformat(
                  _(
                    "Do you really want to apply the settings of the module '%1' to your current system?"
                  ),
                  modulename
                )
              )
              oldMode = Mode.mode
              # The settings will be written in a running system.
              # So we are switching to "normal" mode. (bnc#909223)
              Mode.SetMode("normal")
              # As we are now in "normal" mode and accessing to the target
              # system we have to set StorageDevices flag disks_valid to true.
              # So InitLibstorage can scan valid disks. (bnc#1046738)
              StorageDevices.InitDone

              Call.Function(module_auto, ["Write"])
              Mode.SetMode(oldMode)
            end
          end
        elsif ret == :read
          currentGroup = getGroup
          currentModule = getModule
          resetModule(currentModule)
          readModule(currentModule)
          if UI.WidgetExists(Id(:rp_details))
            # if dialog didn't replace wizard contents this is enough
            updateDetails
          else
            # otherwise we have to rebuild the complete wizard
            CreateDialog(currentGroup, currentModule)
          end
        elsif ret == "menu_tree" # source -> tree
          Builtins.y2debug("change to tree")
          @show_source = false
          Wizard.DeleteMenus # FIXME: sucks sucks sucks sucks sucks
          menus
          CreateDialog(currentGroup, currentModule)
        elsif ret == "menu_open" # OPEN
          filename = UI.AskForExistingFile(
            AutoinstConfig.Repository,
            "*",
            _("Select a file to load.")
          )
          if filename != "" && filename != nil
            AutoinstConfig.currentFile = Convert.to_string(filename)

            pathComponents = Builtins.splitstring(
              Convert.to_string(filename),
              "/"
            )

            s = Ops.subtract(Builtins.size(pathComponents), 1)
            base = Ops.get_string(pathComponents, s, "default")
            readOkay = Profile.ReadXML(Convert.to_string(filename))
            Builtins.y2debug("Profile::ReadXML returned %1", readOkay)
            if readOkay
              Popup.ShowFeedback(
                _("Reading configuration data"),
                _("This may take a while")
              )
              Builtins.foreach(Profile.ModuleMap) do |p, d|
                # Set resource name, if not using default value
                resource = Ops.get_string(d, "X-SuSE-YaST-AutoInstResource", "")
                resource = p if resource == ""
                Builtins.y2debug("resource: %1", resource)
                tomerge = Ops.get_string(d, "X-SuSE-YaST-AutoInstMerge", "")
                module_auto = Ops.get_string(
                  d,
                  "X-SuSE-YaST-AutoInstClient",
                  "none"
                )
                rd = Y2ModuleConfig.getResourceData(d, resource)
                WFM.CallFunction(module_auto, ["Import", rd]) if rd != nil
              end
              Popup.ClearFeedback
              Wizard.DeleteMenus # FIXME: sucks sucks sucks sucks sucks
              menus
            else
              # opening/parsing the xml file failed
              Popup.Error(
                _("An error occurred while opening/parsing the XML file.")
              )
              Profile.Reset
            end
          end
          if UI.WidgetExists(Id(:class_source))
            ShowSource()
          else
            group = getGroup
            modulename = getModule

            contents = Empty()

            if group != ""
              contents = layout(group, modulename)
              caption = @title
              currentFile = AutoinstConfig.currentFile
              currentFile = Builtins.substring(
                currentFile,
                Ops.add(Builtins.findlastof(currentFile, "/"), 1)
              )
              if Ops.greater_than(Builtins.size(currentFile), 0)
                caption = Ops.add(Ops.add(caption, " - "), currentFile)
              end
              Wizard.SetContents(
                caption,
                contents,
                AutoinstConfig.MainHelp,
                true,
                true
              )
              Wizard.SetTitleIcon(
                Ops.get_string(_Icons, group, Builtins.tolower(group))
              )
              updateButtons(modulename)
            end
          end
          ret = :menu_open
        elsif ret == "menu_source" # Show SOURCE
          # save previously selected group and module,
          # so we can restore them afterwards
          @show_source = true
          Wizard.DeleteMenus # FIXME: sucks sucks sucks sucks sucks
          menus
          currentGroup = getGroup
          currentModule = getModule
          ShowSource()
          ret = :menu_source
        elsif ret == "menu_save" # SAVE
          if AutoinstConfig.currentFile == ""
            filename = UI.AskForSaveFileName(
              AutoinstConfig.Repository,
              "*",
              _("Save as...")
            )
            if filename != nil
              AutoinstConfig.currentFile = Convert.to_string(filename)
            else
              next
            end
          end

          if Profile.Save(AutoinstConfig.currentFile)
            Popup.Message(
              Builtins.sformat(
                _("File %1 was saved successfully."),
                AutoinstConfig.currentFile
              )
            )
            #Profile::checkProfile();
            Profile.changed = false
          else
            Popup.Warning(_("An error occurred while saving the file."))
          end
          ret = :menu_save
        elsif ret == "menu_saveas" # SAVE AS
          SaveAs()
          ret = :menu_saveas
        elsif ret == "menu_new" # NEW
          Profile.Reset
          Builtins.foreach(Profile.ModuleMap) do |p, d|
            resource = Ops.get_string(d, "X-SuSE-YaST-AutoInstResource", "")
            resource = p if resource == ""
            resetModule(resource)
          end
          AutoinstConfig.currentFile = ""
          ShowSource() if UI.WidgetExists(Id(:class_source))
          group = getGroup
          module_name = getModule
          Wizard.SetContents(
            _("Available Modules"),
            layout(group, module_name),
            AutoinstConfig.MainHelp,
            true,
            true
          )
          updateButtons(module_name)
          ret = :menu_new
        elsif ret == "change_encryption"
          AutoinstConfig.ProfileEncrypted = !AutoinstConfig.ProfileEncrypted
          AutoinstConfig.ProfilePassword = ""
          Wizard.DeleteMenus # FIXME: sucks sucks sucks sucks sucks
          menus
        elsif ret == "write_to_system"
          if Popup.YesNo(
              _(
                "Do you really want to apply the settings of the profile to your current system?"
              )
            )
            Profile.Prepare
            oldMode = Mode.mode
            oldStage = Stage.stage
            Mode.SetMode("autoinstallation")
            Stage.Set("continue")

            # As we are now in "autoinstallation" mode and accessing to the target
            # system we have to set StorageDevices flag disks_valid to true.
            # So InitLibstorage can scan valid disks. (bnc#1047809)
            StorageDevices.InitDone

            WFM.CallFunction("inst_autopost", [])
            AutoinstSoftware.addPostPackages(
              Ops.get_list(Profile.current, ["software", "post-packages"], [])
            )

            # the following is needed since 10.3
            # otherwise the already configured network gets removed
            if !Builtins.haskey(Profile.current, "networking")
              Profile.current = Builtins.add(
                Profile.current,
                "networking",
                { "keep_install_network" => true }
              )
            end

            Pkg.TargetInit("/", false)
            WFM.CallFunction("inst_rpmcopy", [])
            WFM.CallFunction("inst_autoconfigure", [])
            Mode.SetMode(oldMode)
            Stage.Set(oldStage)
          end
        elsif ret == "menu_exit" || :cancel == ret # EXIT
          ret = :menu_exit
          if Profile.changed
            current = ""
            if AutoinstConfig.currentFile == ""
              current = "Untitled"
            else
              current = AutoinstConfig.currentFile
            end

            answer = Popup.AnyQuestion(
              _("Control file changed."),
              Builtins.sformat(_("Save the changes to %1?"), current),
              Label.YesButton,
              Label.NoButton,
              :focus_yes
            )
            SaveAs() if true == answer
          end
          break
        else
          s = Builtins.toterm(ret)
          ret = Builtins.symbolof(s)
          break
        end
      end
      Convert.to_symbol(ret)
    end
  end
end
