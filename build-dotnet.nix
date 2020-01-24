{ dotnet-sdk, dotnetSdkPackage ? dotnet-sdk, stdenv, makeWrapper, callPackage }:
{ baseName
  , version
  , src
  , additionalWrapperArgs ? ""
  , mono ? ""
  , project ? ""
  , configuration ? "Release"
}:
let fetchDotnet = callPackage ./fetchDotnet.nix { inherit dotnetSdkPackage; };
in
stdenv.mkDerivation rec {
  name = "${baseName}-${version}";
  nativeBuildInputs =  [ dotnetSdkPackage makeWrapper ];
  nugetPackages = fetchDotnet { inherit src name; };
  inherit src mono;
  buildPhase = ''
    runHook preBuild

    if [ "$mono" != "" ]; then
    export FrameworkPathOverride=${mono}/lib/mono/4.5/
    fi

    export DOTNET_CLI_TELEMETRY_OPTOUT=true
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
    # avoid permission denied error
    export HOME=$PWD
    touch $HOME/.dotnet/$(dotnet --version).dotnetFirstUseSentinel


    echo "Running dotnet restore"
    export NUGET_PACKAGES=$nugetPackages
    dotnet restore --locked-mode ${project}
    echo "Running dotnet build"
    dotnet build --no-restore --configuration ${configuration} ${project}

    runHook postBuild
  '';
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    echo Running dotnet publish
    dotnet publish --no-restore --no-build --configuration ${configuration} -o $out ${project}

    echo Creating wrapper
    mkdir $out/bin
    makeWrapper ${dotnetSdkPackage}/bin/dotnet $out/bin/${baseName} --add-flags $out/${baseName}.dll ${additionalWrapperArgs}
    chmod +x $out/bin/${baseName}
    runHook postInstall
  '';
}
