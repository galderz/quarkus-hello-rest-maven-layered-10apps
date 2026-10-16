#!/usr/bin/env bash

LANGUAGES=(
  english
  french
  german
  spanish
  italian
  japanese
  ukrainian
  portuguese
  korean
  swiss
)

HELLO_CLASSES=(
  HelloEnglish
  HelloFrench
  HelloGerman
  HelloSpanish
  HelloItalian
  HelloJapanese
  HelloUkrainian
  HelloPortuguese
  HelloKorean
  HelloSwiss
)

IMAGE_NAMES=(
  hello-english
  hello-french
  hello-german
  hello-spanish
  hello-italian
  hello-japanese
  hello-ukrainian
  hello-portuguese
  hello-korean
  hello-swiss
)

PORTS=(8080 8081 8082 8083 8084 8085 8086 8087 8088 8089)

app_index() {
    local app="$1"
    local i
    for i in "${!LANGUAGES[@]}"; do
        if [[ "${LANGUAGES[$i]}" == "$app" ]]; then
            echo "$i"
            return 0
        fi
    done

    echo "Unsupported APP=$app" >&2
    echo "Supported values: ${LANGUAGES[*]}" >&2
    return 1
}

hello_class_for_app() {
    local index
    index="$(app_index "$1")" || return 1
    echo "${HELLO_CLASSES[$index]}"
}

image_name_for_app() {
    local index
    index="$(app_index "$1")" || return 1
    echo "${IMAGE_NAMES[$index]}"
}

language_for_app() {
    local index
    index="$(app_index "$1")" || return 1
    echo "${LANGUAGES[$index]}"
}

copy_name_for_image() {
    local image_name="$1"
    local copy="$2"
    local copies="$3"

    if [[ "$copies" -eq 1 ]]; then
        echo "$image_name"
    else
        echo "$image_name-$copy"
    fi
}

validate_copies_per_app() {
    local copies="$1"
    if ! [[ "$copies" =~ ^[1-9][0-9]*$ ]]; then
        echo "COPIES_PER_APP must be a positive integer: $copies" >&2
        return 1
    fi
}

layer_library_name() {
    case "$(uname -s)" in
        Darwin)
            echo "libjavabaselayer.dylib"
            ;;
        *)
            echo "libjavabaselayer.so"
            ;;
    esac
}

runtime_library_path_var() {
    case "$(uname -s)" in
        Darwin)
            echo "DYLD_LIBRARY_PATH"
            ;;
        *)
            echo "LD_LIBRARY_PATH"
            ;;
    esac
}

port_for_app() {
    local index
    index="$(app_index "$1")" || return 1
    echo "${PORTS[$index]}"
}

build_base_layer() {
    local root="$1"
    local is_debug="$2"

    (
        echo "==> Building Quarkus non-layered image"
        cd "$root/quarkus-application-layer"
        ../mvnw -Dnative package
    )
    (
        echo "==> Building Quarkus base layer"
        cd "$root/quarkus-base-layer"
        ./build-layer-base.sh "$is_debug"
    )
}

ensure_base_layer_target() {
    local root="$1"
    local is_debug="$2"
    local local_target="$root/quarkus-base-layer/target"
    local layer_library

    layer_library="$(layer_library_name)"

    if [[ -f "$local_target/base-layer.nil" && -f "$local_target/$layer_library" ]]; then
        return 0
    fi

    build_base_layer "$root" "$is_debug"
}

publish_application_artifacts() {
    local root="$1"
    local image_name="$2"
    local copies="${3:-1}"
    local app_target="$root/quarkus-application-layer/target"
    local work_dir="$app_target/$image_name-build"
    local layer_library
    local copy
    local output_name

    mkdir -p "$app_target"
    for ((copy = 1; copy <= copies; copy++)); do
        output_name="$(copy_name_for_image "$image_name" "$copy" "$copies")"
        cp "$work_dir/$image_name" "$app_target/$output_name"
    done
    layer_library="$(layer_library_name)"
    cp "$root/quarkus-base-layer/target/$layer_library" "$app_target/$layer_library"
}
