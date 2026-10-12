#!/usr/bin/env bash
set -ex

mkdir -p target

SRC_JAR_DIR="native/getting-started/target/getting-started-1.0.0-SNAPSHOT-native-image-source-jar"

DEBUG_ARGS=()
if [[ "$1" == "--with-debug=true" ]]; then
    DEBUG_ARGS+=(
        "-g"
#        "-H:+SourceLevelDebug"
#        "-H:+TrackNodeSourcePosition"
#        "-H:+DebugCodeInfoUseSourceMappings"
    )
fi

BASE_ARGS=(
    "--enable-monitoring=heapdump,threaddump"
)

TRACE_ARGS=(
#    "--trace-object-instantiation=io.netty.buffer.EmptyByteBuf"
#    "--trace-object-instantiation=io.netty.handler.codec.compression.BrotliOptions"
#    "--trace-object-instantiation=io.netty.handler.codec.http2.EmptyHttp2Headers"
#    "--trace-object-instantiation=io.netty.handler.codec.quic.QuicCongestionControlAlgorithm"
#    "--trace-object-instantiation=io.netty.handler.ssl.ClientAuth"
)

RUN_INIT_BASE=(
    "io.netty.buffer"
    "io.netty.channel.DefaultChannelId"
    "io.netty.channel.unix.Errors"
    "io.netty.channel.unix.FileDescriptor"
    "io.netty.channel.unix.IovArray"
    "io.netty.channel.unix.Limits"
    "io.netty.handler.codec.ReplayingDecoderByteBuf"
    "io.netty.internal.tcnative"
    "io.netty.util.AbstractReferenceCounted"
    "io.netty.util.NetUtil"
    "io.netty.util.internal.CleanerJava24Linker"
    "io.netty.util.internal.PlatformDependent"
    "io.netty.util.internal.PlatformDependent0"
    "io.quarkus.netty.runtime.EmptyByteBufStub"
    "io.quarkus.runtime.configuration.RuntimeConfigBuilder\$UuidConfigSource\$Holder"
    "io.quarkus.runtime.graal.InetRunTime"
    "io.quarkus.runtime.ExecutorRecorder"
    "io.smallrye.common.os.Process"
    "io.smallrye.common.net.HostName"
    "io.vertx.core.buffer.impl.PartialPooledByteBufAllocator"
    "io.vertx.core.buffer.impl.VertxByteBufAllocator"
    "io.vertx.core.parsetools.impl.RecordParserImpl"
    "jakarta.el.ELManager"
    "java.rmi"
    "java.util.logging.ConsoleHandler"
    "jdk.jpackage.internal.LinuxPackageArch\$DebPackageArch"
    "jdk.jpackage.internal.LinuxPackageArch\$RpmPackageArch"
    "jdk.package"
    "jdk.tools.jlink.internal.plugins"
    "org.jboss.threads.JDKSpecific\$ThreadAccess"
    "org.jboss.logmanager.handlers.ConsoleHandler\$ConsoleHolder"
    "org.jboss.logmanager.handlers.SyslogHandler"
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
    "io.netty.handler.codec.compression.BrotliOptions"
    "io.netty.handler.codec.compression.ZstdConstants"
    "io.netty.handler.codec.compression.ZstdOptions"
    # file
    "io.vertx.core.file.FileSystemOptions"
    # http / http1
    "io.netty.handler.codec.http.HttpContentCompressor"
    "io.netty.handler.codec.http.HttpServerExpectContinueHandler"
    "io.netty.handler.codec.http.HttpObjectAggregator"
    "io.netty.handler.codec.http.HttpObjectEncoder"
    "io.netty.handler.codec.http.websocketx.extensions.compression.DeflateDecoder"
    "io.netty.handler.codec.http.websocketx.WebSocket00FrameEncoder"
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
    # json
    "io.vertx.core.json.Json"
    # jwt
    "io.vertx.ext.auth.impl.jose.JWT"
    # pcap
    "io.netty.handler.pcap.PcapWriteHandler\$WildcardAddressHolder"
    # quick
    "io.netty.handler.codec.quic"
    "io.vertx.core.net.impl.quic"
    # sockjs
    "io.vertx.ext.web.handler.sockjs.impl.XhrTransport"
    # ssl / tls
    "io.netty.handler.ssl"
    "io.vertx.core.internal.tls.SslContextManager"
)

RUN_INIT_FEATURE_ARGS=()
for arg in "${RUN_INIT_FEATURE[@]}"; do
    RUN_INIT_FEATURE_ARGS+=("--initialize-at-run-time=$arg")
done

APP_LAYER_INIT=(
    "io.quarkus.arc.Arc"
    "io.quarkus.smallrye.context.runtime.SmallRyeContextPropagationRecorder"
    "io.quarkus.arc.runtime.ArcRecorder"
    "org.jboss.resteasy.reactive.server.core.RuntimeExceptionMapper"
)

APP_LAYER_INIT_ARGS=()
for arg in "${APP_LAYER_INIT[@]}"; do
    APP_LAYER_INIT_ARGS+=("-H:ApplicationLayerInitializedClasses=${arg}")
done

LAYER_PACKAGE=(
    "package=io.quarkus.*"
    "package=io.netty.*"
    "package=io.vertx.*"
    "package=jakarta.*"
)

LAYER_PACKAGE_ARGS=$(IFS=,; echo "${LAYER_PACKAGE[*]}")

MODULE=(
    "module=java.base"
    "module=jdk.localedata"
)

MODULE_ARGS=$(IFS=,; echo "${MODULE[*]}")

LAYER_ARGS=(
    "--initialize-at-build-time="
    "-H:+PrintClassInitialization"
    "${APP_LAYER_INIT_ARGS[@]}"
    "-H:BuildOutputJSONFile=target/build-output-layer-base.json"
    "-H:LayerCreate=libquarkusbaselayer.nil,${MODULE_ARGS},${LAYER_PACKAGE_ARGS}"
    "-cp" "${SRC_JAR_DIR}/lib/*"
    "-o" "libquarkusbaselayer"
    "-H:Path=./target"
)

${GRAALVM_HOME}/bin/native-image \
    "${BASE_ARGS[@]}" \
    "${TRACE_ARGS[@]}" \
    "${RUN_INIT_BASE_ARGS[@]}" \
    "${RUN_INIT_FEATURE_ARGS[@]}" \
    "${DEBUG_ARGS[@]}" \
    "${LAYER_ARGS[@]}"
