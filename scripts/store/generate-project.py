#!/usr/bin/env python3
"""Generate the small Xcode app target; KeyDockCore stays a local Swift package."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[2]
objects = {}
def uid(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def obj(object_key, isa, **kw):
    key = uid(object_key); objects[key] = dict(isa=isa, **kw); return key
def render(value):
    if isinstance(value, dict): return '{\n' + ''.join(f'{json.dumps(k)} = {render(v)};\n' for k,v in value.items()) + '}'
    if isinstance(value, list): return '(' + ','.join(render(v) for v in value) + ')'
    return json.dumps(value)
sources=[]; files=[]
for path in sorted((root/'Sources/KeyDock').glob('*.swift')):
    relative=str(path.relative_to(root))
    ref=obj(relative,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=relative,sourceTree='<group>')
    files.append(ref); sources.append(obj(relative+' build','PBXBuildFile',fileRef=ref))
resources=[]
for path,kind in [('Resources/KeyDock.icns','image.icns'),('Resources/PrivacyInfo.xcprivacy','text.xml')]:
    ref=obj(path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='<group>')
    files.append(ref); resources.append(obj(path+' build','PBXBuildFile',fileRef=ref))
product=obj('product','PBXFileReference',explicitFileType='wrapper.application',includeInIndex=0,path='KeyDock.app',sourceTree='BUILT_PRODUCTS_DIR')
products=obj('products','PBXGroup',children=[product],name='Products',sourceTree='<group>')
group=obj('root','PBXGroup',children=files+[products],sourceTree='<group>')
package=obj('package','XCLocalSwiftPackageReference',relativePath='.')
core=obj('core','XCSwiftPackageProductDependency',package=package,productName='KeyDockCore')
link=obj('core link','PBXBuildFile',productRef=core)
sourcephase=obj('sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=sources,runOnlyForDeploymentPostprocessing=0)
resourcephase=obj('resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=resources,runOnlyForDeploymentPostprocessing=0)
frameworkphase=obj('frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[link],runOnlyForDeploymentPostprocessing=0)
project_configs=[]; target_configs=[]
for configuration in ['Debug','Release']:
    common={'SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','ARCHS':'arm64','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if configuration=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if configuration=='Debug' else 'dwarf-with-dsym'}
    project_configs.append(obj('project '+configuration,'XCBuildConfiguration',name=configuration,buildSettings=common))
    target={'PRODUCT_NAME':'KeyDock','PRODUCT_BUNDLE_IDENTIFIER':'io.keydock.app','INFOPLIST_FILE':'Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_ENTITLEMENTS':'Resources/KeyDock.entitlements','CODE_SIGN_STYLE':'Automatic','ENABLE_APP_SANDBOX':'YES','ENABLE_HARDENED_RUNTIME':'YES','SWIFT_EMIT_LOC_STRINGS':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks'],'SKIP_INSTALL':'NO','INSTALL_PATH':'$(LOCAL_APPS_DIR)','COMBINE_HIDPI_IMAGES':'YES'}
    target_configs.append(obj('target '+configuration,'XCBuildConfiguration',name=configuration,buildSettings=target))
project_list=obj('project configs','XCConfigurationList',buildConfigurations=project_configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
target_list=obj('target configs','XCConfigurationList',buildConfigurations=target_configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
target=obj('app','PBXNativeTarget',buildConfigurationList=target_list,buildPhases=[sourcephase,frameworkphase,resourcephase],buildRules=[],dependencies=[],name='KeyDock',packageProductDependencies=[core],productName='KeyDock',productReference=product,productType='com.apple.product-type.application')
project=obj('project','PBXProject',attributes={'LastUpgradeCheck':'1600'},buildConfigurationList=project_list,compatibilityVersion='Xcode 14.0',developmentRegion='zh-Hans',hasScannedForEncodings=0,knownRegions=['zh-Hans','en','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',packageReferences=[package],targets=[target])
project_dir=root/'KeyDock.xcodeproj'; project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+render({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n')
scheme_dir=project_dir/'xcshareddata/xcschemes';scheme_dir.mkdir(parents=True,exist_ok=True)
reference=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="KeyDock.app" BlueprintName="KeyDock" ReferencedContainer="container:KeyDock.xcodeproj"/>'
(scheme_dir/'KeyDock.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(project_dir)
