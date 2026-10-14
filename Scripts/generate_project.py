from pathlib import Path
import hashlib, json, plistlib
r=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s):return json.dumps(str(s))
objects={}
def add(name,body):objects[uid(name)]=body;return uid(name)
sources=['Sources/macOS/AKShortcuts.mm','Sources/macOS/ShortcutSettings.swift','Sources/macOS/FirstLoginSetup.swift','Sources/macOS/FeatureNotifications.swift','Sources/macOS/UpdateManifest.swift','Sources/macOS/UpdateTransport.swift','Sources/macOS/UpdateInstaller.swift','Sources/macOS/Updates.swift','Sources/macOS/Licenses.swift','Sources/macOS/Installation.swift','Sources/macOS/LearningStore.swift','Sources/Engine/Engine.cpp','Vendor/Generic/OVIMGeneric.cpp','Sources/macOS/AKInputController.mm','Sources/macOS/Settings.swift','Sources/macOS/main.swift']
sources += ['Vendor/McBopomofo/Source/Engine/Mandarin/Mandarin.cpp','Vendor/McBopomofo/Source/Engine/gramambular2/reading_grid.cpp']
resources=['Resources/Mandarin.sqlite3','Resources/Cangjie5-LICENSE.txt','Resources/McBopomofo-LICENSE.txt','Resources/NewInputs-Attribution.txt','Resources/NotoSansTC-VariableFont_wght.ttf','Resources/NotoSansTC-LICENSE.txt','Resources/NotoSansTC-Attribution.txt','Resources/OpenVanilla-LICENSE.txt','Resources/YahooKeyKey-LICENSE.txt','Resources/ArmKeyKey-LICENSE.txt','Resources/LicensingOverview.txt','Resources/Cantonese.sqlite3','Resources/RimeCantonese-LICENSE.txt','Resources/RimeCantonese-Attribution.txt','Resources/Phrases.txt','Resources/ArmKeyKey.icns','Resources/InputSource.tiff','Resources/TransparentStatusIcon.tiff','Resources/Dictionary.sqlite3','Resources/ThirdPartyNotices.txt','Resources/zh-Hant.lproj/Localizable.strings']
refs=[];builds={'source':[],'resource':[]}
for path in sources+resources:
    kind='source' if path in sources else 'resource'
    typ={'.cpp':'sourcecode.cpp.cpp','.mm':'sourcecode.cpp.objcpp','.swift':'sourcecode.swift','.strings':'text.plist.strings'}.get(Path(path).suffix,'file')
    ref=add(path,f'{{isa = PBXFileReference; lastKnownFileType = {typ}; path = {q(path)}; sourceTree = SOURCE_ROOT; }}');refs.append(ref)
    builds[kind].append(add('build'+path,f'{{isa = PBXBuildFile; fileRef = {ref}; }}'))
product=add('product','{isa=PBXFileReference; explicitFileType=wrapper.application; path=ArmKeyKey.app; sourceTree=BUILT_PRODUCTS_DIR;}')
products=add('products',f'{{isa=PBXGroup; children=({product},); name=Products; sourceTree="<group>";}}')
group=add('group',f'{{isa=PBXGroup; children=({",".join(refs+[products])},); sourceTree="<group>";}}')
phases=[]
for kind,isa in [('source','PBXSourcesBuildPhase'),('resource','PBXResourcesBuildPhase')]:phases.append(add(kind,f'{{isa={isa}; buildActionMask=2147483647; files=({",".join(builds[kind])},); runOnlyForDeploymentPostprocessing=0;}}'))
config={'ALWAYS_SEARCH_USER_PATHS':'NO','PRODUCT_NAME':'ArmKeyKey','PRODUCT_BUNDLE_IDENTIFIER':'everstar.inputmethod.armkeykey.mac','MACOSX_DEPLOYMENT_TARGET':'26.0','SDKROOT':'macosx','ARCHS':'arm64','ONLY_ACTIVE_ARCH':'YES','CLANG_CXX_LANGUAGE_STANDARD':'c++20','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_VERSION':'5.0','SWIFT_OBJC_BRIDGING_HEADER':'Sources/macOS/ArmKeyKey-Bridging-Header.h','HEADER_SEARCH_PATHS':'$(SRCROOT)/Vendor $(SRCROOT)/Sources/Engine','INFOPLIST_FILE':'Resources/Info.plist','CODE_SIGN_STYLE':'Automatic','ENABLE_HARDENED_RUNTIME':'YES','OTHER_LDFLAGS':'-lsqlite3 -framework AppKit -framework InputMethodKit -framework Carbon','GCC_PREPROCESSOR_DEFINITIONS':'OV_USE_SQLITE=1','GENERATE_INFOPLIST_FILE':'NO','SWIFT_STRICT_CONCURRENCY':'targeted'}
configs=[]
for name in ['Debug','Release']:
    c=dict(config,SWIFT_OPTIMIZATION_LEVEL='-Onone' if name=='Debug' else '-O',GCC_OPTIMIZATION_LEVEL='0' if name=='Debug' else 's')
    configs.append(add(name,'{isa=XCBuildConfiguration; name='+name+'; buildSettings={'+''.join(k+'='+q(v)+';' for k,v in c.items())+'};}'))
cl=add('configs',f'{{isa=XCConfigurationList; buildConfigurations=({",".join(configs)},); defaultConfigurationIsVisible=0; defaultConfigurationName=Release;}}')
target=add('target',f'{{isa=PBXNativeTarget; buildConfigurationList={cl}; buildPhases=({",".join(phases)},); buildRules=(); dependencies=(); name=ArmKeyKey; productName=ArmKeyKey; productReference={product}; productType="com.apple.product-type.application";}}')
project=add('project',f'{{isa=PBXProject; attributes={{LastUpgradeCheck=2700;}}; buildConfigurationList={cl}; compatibilityVersion="Xcode 14.0"; developmentRegion="zh-Hant"; hasScannedForEncodings=0; knownRegions=("zh-Hant",Base); mainGroup={group}; productRefGroup={products}; projectDirPath=""; projectRoot=""; targets=({target},);}}')
folder=r/'ArmKeyKey.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1; classes={}; objectVersion=56; objects={\n'+''.join(k+' = '+v+';\n' for k,v in objects.items())+'}; rootObject='+project+';}\n')
info={'CFBundleDevelopmentRegion':'zh-Hant','CFBundleLocalizations':['zh-Hant'],'CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleIconFile':'ArmKeyKey','tsInputMethodIconFileKey':'TransparentStatusIcon.tiff','TISIconIsTemplate':False,'CFBundleName':'ArmKeyKey','CFBundleDisplayName':'ArmKeyKey','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.10.0','CFBundleVersion':'21','LSMinimumSystemVersion':'26.0','LSUIElement':True,'NSPrincipalClass':'NSApplication','InputMethodConnectionName':'ArmKeyKey_Connection','InputMethodServerControllerClass':'AKInputController','InputMethodServerDelegateClass':'AKInputController','TISInputSourceID':'$(PRODUCT_BUNDLE_IDENTIFIER)','TISIntendedLanguage':'zh-Hant','tsInputMethodCharacterRepertoireKey':['Hant'],'tsInputMethodPrimaryInScriptKey':True,'tsInputMethodLanguageKey':'zh-Hant','NSHumanReadableCopyright':'Copyright © 2026 jr-everstar. Includes third-party software and data; see bundled license notices.'}
(r/'Resources/Info.plist').write_bytes(plistlib.dumps(info))
