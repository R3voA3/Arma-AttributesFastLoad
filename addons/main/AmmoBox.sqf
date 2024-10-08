#include "\a3\3DEN\UI\dikCodes.inc"

#define VALUE_NUMBER "#(argb,1,1,1)color(0,0,0,0)"
#define COLUMNS 3

#define SYMBOL_VIRTUAL_0 "-"
#define SYMBOL_VIRTUAL_1 "∞"

params ["_mode", "_params"];

switch _mode do
{
    case "onLoad":
    {
        //--- Selected ammobox
        private _entity = get3DENSelected "object" select 0;

        //--- Get current cargo
        private _cargo =
        [
            getWeaponCargo _entity,
            getMagazineCargo _entity,
            getItemCargo _entity,
            getBackpackCargo _entity
        ];

        //--- Get virtual cargo (only when no default cargo is present)
        AmmoBox_type = 0;
        if ({count (_x select 0) > 0} count _cargo == 0) then
        {
            private _virtualCargo =
            [
                _entity call bis_fnc_getVirtualWeaponCargo,
                _entity call bis_fnc_getVirtualMagazineCargo,
                _entity call bis_fnc_getVirtualItemCargo,
                _entity call bis_fnc_getVirtualBackpackCargo
            ];

            //--- Virtual cargo is empty as well, keep default cargo selected
            if ({count (_x select 0) > 0} count _virtualCargo == 0) exitWith {};

            AmmoBox_type = 1;
            {
                _xCargo = _cargo select _foreachindex;
                {
                    _index = (_xCargo select 0) find _x;
                    if (_index < 0) then {
                        (_xCargo select 0) pushBack _x;
                        (_xCargo select 1) pushBack 1;
                    };
                } forEach _x;
            } forEach _virtualCargo;
        };

        RscAttributeInventory_cargo = [[], []];
        {
            RscAttributeInventory_cargo set [0, (RscAttributeInventory_cargo select 0) + (_x select 0)];
            RscAttributeInventory_cargo set [1, (RscAttributeInventory_cargo select 1) + (_x select 1)];
        } forEach _cargo;

        _classes = RscAttributeInventory_cargo select 0;
        {_classes set [_foreachindex, toLower _x];} forEach _classes;

        //--- Init UI
        _ctrlGroup = _params select 0;
        (ctrlParent _ctrlGroup) displayAddEventHandler ["KeyDown", {with uiNamespace do {['KeyDown', [AmmoBox_ctrlGroup, _this select 1, _this select 2, _this select 3], objNull] call AmmoBox_script;};}];
        //_ctrlGroup ctrladdeventhandler ["KeyDown", {with uinamespace do {['KeyDown', _this, objnull] call AmmoBox_script;};}];
        _ctrlGroup ctrlAddEventHandler ["SetFocus", {with uiNamespace do {AmmoBox_ctrlGroup = _this select 0;};}];
        _ctrlGroup ctrlAddEventHandler ["KillFocus", {with uiNamespace do {AmmoBox_ctrlGroup = nil;};}];

        _ctrlType = _ctrlGroup controlsGroupCtrl 103;
        _ctrlType ctrlAddEventHandler ["ToolBoxSelChanged", {with uiNamespace do {['typeChanged', _this, objNull] call AmmoBox_script;};}];
        _ctrlType lbSetCurSel AmmoBox_type;
        ["typeChanged", [_ctrlType, AmmoBox_type], objNull] call AmmoBox_script;

        _ctrlFilter = _ctrlGroup controlsGroupCtrl 100;
        _ctrlFilter ctrlAddEventHandler ["ToolBoxSelChanged", {with uiNamespace do {['filterChanged', _this, objNull] call AmmoBox_script;};}];
        ["filterChanged", [_ctrlFilter, 0], objNull] call AmmoBox_script;

        _ctrlList = _ctrlGroup controlsGroupCtrl 101;
        _ctrlList ctrlAddEventHandler ["LBSelChanged", {with uiNamespace do {["listSelect", [ctrlParentControlsGroup (_this select 0)], objNull] call AmmoBox_script;};}];
        _ctrlList ctrlAddEventHandler ["LBDblClick", {with uiNamespace do {["listModify", [ctrlParentControlsGroup (_this select 0), +1], objNull] call AmmoBox_script;};}];

        _ctrlArrowLeft = _ctrlGroup controlsGroupCtrl 313102;
        _ctrlArrowLeft ctrlAddEventHandler ["ButtonClick", {with uiNamespace do {["listModify", [ctrlParentControlsGroup (_this select 0), -1], objNull] call AmmoBox_script;};}];
        _ctrlArrowRight = _ctrlGroup controlsGroupCtrl 313103;
        _ctrlArrowRight ctrlAddEventHandler ["ButtonClick", {with uiNamespace do {["listModify", [ctrlParentControlsGroup (_this select 0), +1], objNull] call AmmoBox_script;};}];

        _ctrlButtonCustom = _ctrlGroup controlsGroupCtrl 104;
        _ctrlButtonCustom ctrlSetText localize "str_disp_arcmap_clear";
        _ctrlButtonCustom ctrlAddEventHandler ["ButtonClick", {with uiNamespace do {["clear", [ctrlParentControlsGroup (_this select 0)], objNull] call AmmoBox_script;};}];

        if (isNil "AmmoBox_list") then
        {
            [ctrlParentControlsGroup (_params select 0)] spawn
            {
                disableSerialization;
                startLoadingScreen ["", "RscDisplayLoadMission"];

                //--- Get weapons and magazines from curator addons
                private _types =
                [
                    ["AssaultRifle", "Shotgun", "Rifle", "SubmachineGun"],
                    ["MachineGun"],
                    ["SniperRifle"],
                    ["Launcher", "MissileLauncher", "RocketLauncher"],
                    ["Handgun"],
                    ["UnknownWeapon"],
                    ["AccessoryMuzzle", "AccessoryPointer", "AccessorySights", "AccessoryBipod"],
                    ["Uniform"],
                    ["Vest"],
                    ["Backpack"],
                    ["Headgear", "Glasses"],
                    ["Binocular", "Compass", "FirstAidKit", "GPS", "LaserDesignator", "Map", "Medikit", "MineDetector", "NVGoggles", "Radio", "Toolkit", "Watch", "UAVTerminal"]
                ];

                private _CfgWeapons = configFile >> "CfgWeapons";
                private _list = [[], [], [], [], [], [], [], [], [], [], [], []];

                //--- Weapons, magazines and items
                private _magazines = []; //--- Store magazines in an array and mark duplicates, so nthey don't appear in the list of all items

                private _glassesArray = "true" configClasses (configFile >> "CfgGlasses");
                private _weaponsArray = "true" configClasses _CfgWeapons;
                private _vehiclesArray = "true" configClasses (configFile >> "CfgVehicles");

                private _k = 1 / (count _weaponsArray + count _vehiclesArray + count _glassesArray);
                private _progress = 0;

                private _fnc_progressLoadingScreen =
                {
                    _progress = _progress + _k;
                    progressLoadingScreen _progress;
                };

                {
                    private _weaponCfg = _x;
                    private _weapon = toLower configName _weaponCfg;

                    _weapon call bis_fnc_itemType params ["_weaponTypeCategory", "_weaponTypeSpecific"];

                    {
                        if (_weaponTypeSpecific in _x) exitWith
                        {
                            if !(_weaponTypeCategory isEqualTo "VehicleWeapon") then
                            {
                                private _weaponPublic = getNumber (_weaponCfg >> "scope") isEqualTo 2;
                                private _listType = _list select _forEachIndex;

                                if (_weaponPublic) then
                                {
                                    _listType pushBack
                                    [
                                        ([getText (_weaponCfg >> "displayName")] + (((_weaponCfg >> "linkeditems") call bis_fnc_returnchildren) apply { getText (_CfgWeapons >> getText (_x >> "item") >> "displayName") })) joinString " + ",
                                        _weapon,
                                        getText (_weaponCfg >> "picture"),
                                        parseNumber (getNumber (_weaponCfg >> "type") in [4096, 131072]),
                                        false
                                    ];
                                };

                                //--- Add magazines compatible with the weapon
                                if (_weaponPublic || _weapon in ["throw", "put"]) then
                                {
                                    {
                                        private _muzzle = if (_x == "this") then { _weaponCfg } else { _weaponCfg >> _x };
                                        private _magazinesList = getArray (_muzzle >> "magazines");

                                        // Add magazines from magazine wells
                                        { { _magazinesList append (getArray _x) } forEach configProperties [configFile >> "CfgMagazineWells" >> _x, "isArray _x"] } forEach getArray (_muzzle >> "magazineWell");

                                        {
                                            private _mag = toLower _x;

                                            if (_listType findIf { _x select 1 == _mag } < 0) then
                                            {
                                                private _magCfg = configFile >> "CfgMagazines" >> _mag;

                                                if (getNumber (_magCfg >> "scope") isEqualTo 2) then
                                                {
                                                    _listType pushBack
                                                    [
                                                        getText (_magCfg >> "displayName"),
                                                        _mag,
                                                        getText (_magCfg >> "picture"),
                                                        2,
                                                        _mag in _magazines
                                                    ];

                                                    _magazines pushBack _mag;
                                                };
                                            };
                                        }
                                        forEach _magazinesList;
                                    }
                                    forEach getArray (_weaponCfg >> "muzzles");
                                };
                            };
                        };
                    }
                    forEach _types;

                    call _fnc_progressLoadingScreen;
                }
                forEach _weaponsArray;

                //--- Backpacks
                {
                    private _weaponCfg = _x;
                    private _weapon = toLower configName _weaponCfg;

                    _weapon call bis_fnc_itemType params ["", "_weaponTypeSpecific"];

                    {
                        if (_weaponTypeSpecific in _x) exitWith
                        {
                            if (getNumber (_weaponCfg >> "scope") == 2) then
                            {
                                _list select _forEachIndex pushBack
                                [
                                    getText (_weaponCfg >> "displayName"),
                                    _weapon,
                                    getText (_weaponCfg >> "picture"),
                                    3,
                                    false
                                ];
                            };
                        };
                    }
                    forEach _types;

                    call _fnc_progressLoadingScreen;
                }
                forEach _vehiclesArray;

                //--- Glasses
                {
                    private _weaponCfg = _x;
                    private _weapon = toLower configName _weaponCfg;

                    if (getNumber (_weaponCfg >> "scope") == 2) then
                    {
                        _list select 10 pushBack
                        [
                            getText (_weaponCfg >> "displayName"),
                            _weapon,
                            getText (_weaponCfg >> "picture"),
                            3,
                            false
                        ];
                    };

                    call _fnc_progressLoadingScreen;
                }
                forEach _glassesArray;

                AmmoBox_list = _list;

                ["filterChanged", [_this select 0, AmmoBox_filter], objNull] call AmmoBox_script;

                endLoadingScreen;
            };
        };
    };

    case "typeChanged":
    {
        _ctrlType = _params select 0;
        _ctrlGroup = ctrlParentControlsGroup _ctrlType;
        _type = _params select 1;
        AmmoBox_type = _type;

        _ctrlArrowLeft = _ctrlGroup controlsGroupCtrl 313102;
        _ctrlArrowLeft ctrlSetText (["-", SYMBOL_VIRTUAL_0] select (_type > 0));
        //_ctrlArrowLeft ctrlenable (_value > -1);

        _ctrlArrowRight = _ctrlGroup controlsGroupCtrl 313103;
        _ctrlArrowRight ctrlSetText (["+", SYMBOL_VIRTUAL_1] select (_type > 0));
        //_ctrlArrowRight ctrlenable (_value > -1);

        ["filterChanged", [_ctrlGroup, AmmoBox_filter], objNull] call AmmoBox_script;
    };

    case "filterChanged":
    {
        private _cursel = if (count _params > 1) then { _params select 1 } else { AmmoBox_filter };
        AmmoBox_filter = _cursel;

        private _ctrlGroup = ctrlParentControlsGroup (_params select 0);
        private _ctrlList = _ctrlGroup controlsGroupCtrl 101;
        //_ctrlLoad = _ctrlGroup controlsGroupCtrl 102;
        //_ctrlFilterBackground = _ctrlGroup controlsGroupCtrl IDC_RSCATTRIBUTEINVENTORY_FILTERBACKGROUND;
        private _list = uiNamespace getVariable ["AmmoBox_list", [[], [], [], [], [], [], [], [], [], [], [], []]];

        lnbClear _ctrlList;

        {
            private _types = _x;
            private _indexes = switch (_forEachIndex) do
            {
                case 1: { [6, 7, 8, 9, 10, 11] };
                default { [0, 1, 2, 3, 4, 5] };
            };

            {
                private _items = if (_cursel > 0) then
                {
                    if (_cursel - 1 != _x) then
                    {
                        continue;
                    };
                    _list select _x
                }
                else
                {
                    _list select _x
                };
                RscAttributeInventory_cargo params ["_classes", "_values"];
                {
                    _x params ["_displayName", "_class", "_picture", "_type", "_isDuplicate"];

                    if (_type in _types && (!_isDuplicate || _cursel > 0)) then
                    {
                        private _index = _classes find _class;
                        private _value = if (_index < 0) then
                        {
                            if (_cursel == 0) then
                            {
                                continue;
                            };
                            _index = count _classes;
                            _classes set [_index, _class];
                            _values set [_index, 0];
                            0
                        } else {
                            _values select _index
                        };

                        if ((_cursel == 0 && _value != 0) || (_cursel > 0)) then
                        {
                            private _valueText = if (AmmoBox_type > 0) then { [SYMBOL_VIRTUAL_0, SYMBOL_VIRTUAL_1] select (_value > 0) } else { str _value };
                            private _lnbAdd = _ctrlList lnbAddRow ["", _displayName, _valueText, ""];
                            _ctrlList lnbSetData [[_lnbAdd, 0], _class];
                            _ctrlList lnbSetValue [[_lnbAdd, 0], _value];
                            _ctrlList lnbSetValue [[_lnbAdd, 1], _type];
                            _ctrlList lnbSetPicture [[_lnbAdd, 0], _picture];
                            private _alpha = [0.5, 1] select (_value != 0);
                            _ctrlList lnbSetColor [[_lnbAdd, 1], [1, 1, 1, _alpha]];
                            _ctrlList lnbSetColor [[_lnbAdd, 2], [1, 1, 1, _alpha]];
                            _ctrlList lnbSetTooltip [[_lnbAdd, 0], _displayName];

                            //if (_cursel == 0 && _value != 0) then
                            //{
                                //_coef = switch _type do
                                //{
                                    //case 0: {RscAttributeInventory_loadWeapon};
                                    //case 1: {0};
                                    //case 2: {RscAttributeInventory_loadMagazine};
                                    //case 3: {RscAttributeInventory_loadBackpack};
                                    //default {0};
                                //};
                                //_ctrlLoad progresssetposition (progressposition _ctrlLoad + (_value max 0) * _coef);
                            //};
                        };
                    };
                }
                forEach _items;
            }
            forEach _indexes;
        }
        forEach [[0], [1, 3], [2]]; // 0 - Weapons, 1 - Items, 2 - Magazines, 3 - Backpacks

        _ctrlList lnbSort [1, false];
        _ctrlList lnbSetCurSelRow 0;

        ["listSelect", [_ctrlGroup], objNull] call AmmoBox_script;
    };

    case "listModify":
    {
        _ctrlGroup = _params select 0;
        _add = _params select 1;

        _ctrlList = _ctrlGroup controlsGroupCtrl 101;
        //_ctrlLoad = _ctrlGroup controlsGroupCtrl 102;
        _cursel = lnbCurSelRow _ctrlList;
        _class = _ctrlList lnbData [_cursel, 0];
        _value = _ctrlList lbValue (_cursel * COLUMNS); //--- ToDo: Use lnbValue once it's fixed
        _type = _ctrlList lbValue (_cursel * COLUMNS + 1); //--- ToDo: Use lnbValue once it's fixed

        _classes = RscAttributeInventory_cargo select 0;
        _values = RscAttributeInventory_cargo select 1;
        _index = _classes find _class;
        if (_index >= 0) then {
            //_coef = switch _type do {
                //case 0: {RscAttributeInventory_loadWeapon};
                //case 1: {0};
                //case 2: {RscAttributeInventory_loadMagazine};
                //case 3: {RscAttributeInventory_loadBackpack};
                //default {0};
            //};

            if (AmmoBox_type > 0) then {
                _value = if (_add > 0) then {1} else {0};
                _ctrlList lnbSetText [[_cursel, 2], [SYMBOL_VIRTUAL_0, SYMBOL_VIRTUAL_1] select (_value > 0)];
            } else {
                _value = (_value + _add) max 0;
                //_load = progressposition _ctrlLoad + _add * _coef;
                _load = 0;
                if ((_load <= 1 && _value >= 0) || _value == 0) then {
                    //if (_value > 0 || (_value == 0 && _add < 0)) then {_ctrlLoad progresssetposition _load};
                    _valueText = if (AmmoBox_type > 0) then {[SYMBOL_VIRTUAL_0, SYMBOL_VIRTUAL_1] select (_value > 0)} else {str _value};
                    _ctrlList lnbSetText [[_cursel, 2], str _value];
                };
            };
            _values set [_index, _value];
            _ctrlList lnbSetValue [[_cursel, 0], _value];
            _alpha = [0.5, 1] select (_value != 0);
            _ctrlList lnbSetColor [[_cursel, 1], [1, 1, 1, _alpha]];
            _ctrlList lnbSetColor [[_cursel, 2], [1, 1, 1, _alpha]];
            ["listSelect", [_ctrlGroup], objNull] call AmmoBox_script;
        };
    };

    case "listSelect":
    {
        private ["_ctrlGroup", "_ctrlList", "_cursel", "_value", "_ctrlArrowLeft", "_buttonText"];
        _ctrlGroup = _params select 0;
        _ctrlList = _ctrlGroup controlsGroupCtrl 101;
        _cursel = lnbCurSelRow _ctrlList;
        _value = _ctrlList lbValue (_cursel * COLUMNS); //--- ToDo: Use lnbValue once it's fixed
    };

    case "clear":
    {
        _classes = RscAttributeInventory_cargo select 0;
        _values = RscAttributeInventory_cargo select 1;

        if (AmmoBox_filter > 0) then {
            //--- Clear items in selected category
            _list = uiNamespace getVariable ["AmmoBox_list", [[], [], [], [], [], [], [], [], [], [], [], []]];
            _items = _list select (AmmoBox_filter - 1);
            {
                _class = _x select 1;
                _classID = _classes find _class;
                if (_classID >= 0) then {
                    _values set [_classID, 0];
                };
            } forEach _items;
        } else {
            //--- Clear all
            {
                _values set [_foreachindex, 0];
            } forEach _values;
        };
        ["filterChanged", _params, objNull] call AmmoBox_script;
    };

    case "KeyDown":
    {
        _ctrlGroup = _params select 0;
        if !(isNil "_ctrlGroup") then {
            _key = _params select 1;
            _ctrl = _params select 3;
            switch _key do {
                case DIK_LEFT;
                case DIK_NUMPADMINUS: {
                    ["listModify", [ctrlParentControlsGroup (_params select 0), if (_ctrl) then {-5} else {-1}], objNull] call AmmoBox_script;
                    true
                };
                case DIK_RIGHT;
                case DIK_NUMPADPLUS: {
                    ["listModify", [ctrlParentControlsGroup (_params select 0), if (_ctrl) then {+5} else {+1}], objNull] call AmmoBox_script;
                    true
                };
                default {false};
            };
        } else {
            false
        };
    };

    // case "attributeLoad":
    // {
    // };

    case "attributeSave":
    {

        //--- Sort items into categories and save. Will be loaded by BIS_fnc_initAmmoBox
        _cargo = uiNamespace getVariable ["RscAttributeInventory_cargo", [[], []]];
        _cargoClasses = _cargo select 0;
        _cargoValues = _cargo select 1;
        _outputClasses = [[], [], [], []]; // weapons, magazines, items, backpacks
        _outputValues = [[], [], [], []];
        _output = [[[], []], [[], []], [[], []], [[], []]];
        _isVirtual = (uiNamespace getVariable ["AmmoBox_type", 0]) > 0;
        {
            if (_x != 0) then {
                _class = _cargoClasses select _foreachindex;
                _index = switch true do {
                    case (getNumber (configFile >> "cfgweapons" >> _class >> "type") in [4096, 131072]): {
                        _class = configName (configFile >> "cfgweapons" >> _class);
                        [2, 6] select (_x < 0);
                    };
                    case (isClass (configFile >> "cfgweapons" >> _class)): {
                        _class = configName (configFile >> "cfgweapons" >> _class);
                        [0, 4] select (_x < 0);
                    };
                    case (isClass (configFile >> "cfgmagazines" >> _class)): {
                        _class = configName (configFile >> "cfgmagazines" >> _class);
                        [1, 5] select (_x < 0);
                    };
                    case (isClass (configFile >> "cfgvehicles" >> _class)): {
                        _class = configName (configFile >> "cfgvehicles" >> _class);
                        [3, 7] select (_x < 0);
                    };
                    case (isClass (configFile >> "cfgglasses" >> _class)): {
                        _class = configName (configFile >> "cfgglasses" >> _class);
                        [2, 6] select (_x < 0);
                    };
                    default {-1};
                };
                if (_index >= 0) then {
                    (_outputClasses select _index) pushBack _class;
                    (_outputValues select _index) pushBack _x;

                    _arrayType = _output select _index;
                    (_arrayType select 0) pushBack _class;
                    if !(_isVirtual) then {(_arrayType select 1) pushBack _x;};
                };
            };
        } forEach _cargoValues;
        str [_output, _isVirtual] //--- Save as a string. Serialized array takes too much space.
    };
};
