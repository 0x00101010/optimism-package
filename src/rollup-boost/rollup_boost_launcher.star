ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

ENTRYPOINT_ARGS = ["/usr/local/bin/rollup-boost"]

ROLLUP_BOOST_IMAGE_NAME="0x00101010/rollup-boost:latest"
ROLLUP_BOOST_SERVICE_NAME="op-rollup-boost"
ROLLUP_BOOST_RPC_PORT_NUM=10101

def launch(
    plan,
    sequencer_el_context,
    builder_el_context,
    jwt_file,
):
    config = get_rollup_boost_config(
        plan,
        sequencer_el_context,
        builder_el_context,
        jwt_file,
    )
    plan.print(config)

    service = plan.add_service(ROLLUP_BOOST_SERVICE_NAME, config)

    return config

def get_rollup_boost_config(
    plan,
    sequencer_el_context,
    builder_el_context,
    jwt_file,
):
    cmd = [
        "--l2-url={0}".format(sequencer_el_context.rpc_http_url),
        "--builder-url={0}".format(builder_el_context.rpc_http_url),
        "--jwt-path={0}".format(ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER),
        # "--builder-jwt-path",
        # ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--rpc-port={0}".format(ROLLUP_BOOST_RPC_PORT_NUM),
        "--metrics"
    ]

    files = {
        ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    ports = {
        "rpc": ethereum_package_shared_utils.new_port_spec(
            ROLLUP_BOOST_RPC_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }

    return ServiceConfig(
        image=ROLLUP_BOOST_IMAGE_NAME,
        files=files,
        ports=ports,
        cmd=cmd,
        entrypoint=ENTRYPOINT_ARGS,
    )
