#!/usr/bin/env bash
set -ex

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

app_image_name=$1
build_dir="${ROOT}/target/${app_image_name}-build"

SRC_JAR_DIR="${build_dir}/native-sources"

DEBUG_ARGS=()
if [[ "$2" == "--with-debug=true" ]]; then
    DEBUG_ARGS+=(
        "-g"
#        "-H:+SourceLevelDebug"
#        "-H:+TrackNodeSourcePosition"
#        "-H:+DebugCodeInfoUseSourceMappings"
    )
fi

BASE_ARGS=(
    "-J-Djava.util.logging.manager=org.jboss.logmanager.LogManager"
    "-J-Dsun.nio.ch.maxUpdateArraySize=100"
    "-J-Dvertx.logger-delegate-factory-class-name=io.quarkus.vertx.core.runtime.VertxLogDelegateFactory"
    "-J-Dvertx.disableDnsResolver=true"
    "-J-Dio.netty.tryReflectionSetAccessible=true"
    "-J-Dio.netty.noUnsafe=true"
    "-J-Dio.netty.leakDetection.level=DISABLED"
    "-J-Dio.netty.allocator.maxOrder=3"
    "-J-Duser.language=en"
    "-J-Dlogging.initial-configurator.min-level=500" "-H:+UnlockExperimentalVMOptions"
    "-H:IncludeLocales=en" "-H:-UnlockExperimentalVMOptions"
    "--enable-native-access=ALL-UNNAMED"
    "-J-Dfile.encoding=UTF-8"
    "-J--add-exports=org.graalvm.nativeimage.builder/com.oracle.svm.core.jdk=ALL-UNNAMED"
    "--features=io.quarkus.runner.Feature,io.quarkus.runtime.graal.DisableLoggingFeature,io.quarkus.runtime.graal.JVMChecksFeature,io.quarkus.runtime.graal.SkipConsoleServiceProvidersFeature"
    "-J--add-exports=java.security.jgss/sun.security.krb5=ALL-UNNAMED"
    "-J--add-exports=java.security.jgss/sun.security.jgss=ALL-UNNAMED"
    "-J--add-opens=java.base/java.text=ALL-UNNAMED"
    "-J--add-opens=java.base/java.io=ALL-UNNAMED"
    "-J--add-opens=java.base/java.lang.invoke=ALL-UNNAMED"
    "-J--add-opens=java.base/java.util=ALL-UNNAMED" "-H:+UnlockExperimentalVMOptions"
    "-H:BuildOutputJSONFile=target/build-output-layer-app.json" "-H:-UnlockExperimentalVMOptions" "-H:+UnlockExperimentalVMOptions"
    "-H:+GenerateBuildArtifactsFile" "-H:-UnlockExperimentalVMOptions"
    "-H:+PrintClassInitialization"
    "-H:-CheckToolchain" "-H:+UnlockExperimentalVMOptions"
    "-H:+AllowFoldMethods" "-H:-UnlockExperimentalVMOptions" "-H:+UnlockExperimentalVMOptions"
    "-H:+SharedArenaSupport" "-H:-UnlockExperimentalVMOptions"
    "-J-Djava.awt.headless=true"
    "-H:+UnlockExperimentalVMOptions"
    "-H:+ReportExceptionStackTraces" "-H:-UnlockExperimentalVMOptions"
    "-H:-AddAllCharsets"
    "--enable-url-protocols=http"
    "-H:NativeLinkerOption=-no-pie"
    "--enable-monitoring=heapdump,threaddump" "-H:+UnlockExperimentalVMOptions"
    "-H:-UseServiceLoaderFeature" "-H:-UnlockExperimentalVMOptions"
    "--exclude-config" 'io\.netty\.netty-codec.*' '/META-INF/native-image/io\.netty/netty-codec.*/generated/handlers/reflect-config\.json'
    "--exclude-config" 'io\.netty\.netty-handler' '/META-INF/native-image/io\.netty/netty-handler/generated/handlers/reflect-config\.json'
)

RUN_INIT_BASE=(
    "io.netty.buffer"
    "io.netty.handler.timeout"
    "io.netty.handler.traffic"
    "io.netty.util.NetUtil"
    "io.netty.util.internal.PlatformDependent"
    "io.netty.util.internal.PlatformDependent0"
    "io.vertx.ext.web.handler.impl"
    "org.jboss.logmanager.handlers.ConsoleHandler\$ConsoleHolder"
    "org.jboss.logmanager.handlers.SyslogHandler"
    "jakarta.el.ELManager"
    "java.rmi"
    "jdk.jpackage.internal.LinuxPackageArch\$DebPackageArch"
    "jdk.jpackage.internal.LinuxPackageArch\$RpmPackageArch"
    "jdk.tools.jlink.internal.plugins"
    "sun.rmi"
)

RUN_INIT_BASE_ARGS=()
for arg in "${RUN_INIT_BASE[@]}"; do
    RUN_INIT_BASE_ARGS+=("--initialize-at-run-time=$arg")
done

RUN_INIT_FEATURE=(
    # clustered eventbus
    "io.vertx.core.eventbus.impl.clustered"
    # compression
    "io.netty.handler.codec.compression"
    # dns
    "io.netty.resolver.dns"
    # http / http1
    "io.netty.handler.codec.http"
    "io.vertx.core.http.impl.ClientMultipartFormUpload"
    "io.vertx.core.http.impl.Http1xServerResponse"
    "io.vertx.core.http.impl.VertxHttp2ClientUpgradeCodec"
    "io.vertx.core.http.impl.http1.Http1ServerResponse"
    "io.vertx.core.http.impl.tcp.VertxHttp2ClientUpgradeCodec"
    # http2
    "io.netty.handler.codec.http2"
    "io.vertx.core.http.impl.http2"
    # http3
    "io.vertx.core.http.impl.http3.Http3Stream"
    # marshalling
    "io.netty.handler.codec.marshalling"
    # proxy
    "io.netty.handler.proxy"
    # quick
    "io.netty.handler.codec.quic"
    "io.vertx.core.net.impl.quic"
    # rtsp
    "io.netty.handler.codec.rtsp"
    # socks
    "io.netty.handler.codec.socks"
    # spdy
    "io.netty.handler.codec.spdy"
    "io.netty.handler.pcap.PcapWriteHandler\$WildcardAddressHolder"
    # ssl / tls
    "io.netty.handler.ssl"
    "io.vertx.core.internal.tls.SslContextManager"
)

RUN_INIT_FEATURE_ARGS=()
for arg in "${RUN_INIT_FEATURE[@]}"; do
    RUN_INIT_FEATURE_ARGS+=("--initialize-at-run-time=$arg")
done

LAYER_ARGS=(
    "-H:LayerUse=../quarkus-base-layer/target/base-layer.nil"
    "-H:LinkerRPath=."
    "-jar" "${SRC_JAR_DIR}/${app_image_name}-runner.jar"
    "-o" "${app_image_name}"
    "-H:Path=${build_dir}"
)

# Copy original sources over
if [[ "$1" == "--with-debug=true" ]]; then
    cp -r ./${SRC_JAR_DIR}/sources target
fi

${GRAALVM_HOME}/bin/native-image \
    "${BASE_ARGS[@]}" \
    "${RUN_INIT_BASE_ARGS[@]}" \
    "${RUN_INIT_FEATURE_ARGS[@]}" \
    "${DEBUG_ARGS[@]}" \
    "${LAYER_ARGS[@]}"
