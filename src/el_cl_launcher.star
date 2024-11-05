ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

ethereum_package_el_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_context.star"
)

# EL
op_geth = import_module("./el/op-geth/op_geth_launcher.star")
op_reth = import_module("./el/op-reth/op_reth_launcher.star")
op_erigon = import_module("./el/op-erigon/op_erigon_launcher.star")
op_nethermind = import_module("./el/op-nethermind/op_nethermind_launcher.star")
op_besu = import_module("./el/op-besu/op_besu_launcher.star")
# CL
op_node = import_module("./cl/op-node/op_node_launcher.star")
hildr = import_module("./cl/hildr/hildr_launcher.star")

# rollup-boost
rollup_boost = import_module("./rollup-boost/rollup_boost_launcher.star")


def launch(
    plan,
    jwt_file,
    network_params,
    deployment_output,
    participants,
    num_participants,
    l1_config_env_vars,
    l2_services_suffix,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
):
    el_launchers = {
        "op-geth": {
            "launcher": op_geth.new_op_geth_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_geth.launch,
        },
        "op-reth": {
            "launcher": op_reth.new_op_reth_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_reth.launch,
        },
        "op-erigon": {
            "launcher": op_erigon.new_op_erigon_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_erigon.launch,
        },
        "op-nethermind": {
            "launcher": op_nethermind.new_nethermind_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_nethermind.launch,
        },
        "op-besu": {
            "launcher": op_besu.new_op_besu_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_besu.launch,
        },
    }

    cl_launchers = {
        "op-node": {
            "launcher": op_node.new_op_node_launcher(
                deployment_output, jwt_file, network_params
            ),
            "launch_method": op_node.launch,
        },
        "hildr": {
            "launcher": hildr.new_hildr_launcher(
                deployment_output, jwt_file, network_params
            ),
            "launch_method": hildr.launch,
        },
    }

    all_cl_contexts = []
    all_el_contexts = []
    sequencer_enabled = True
    for index, participant in enumerate(participants):
        cl_type = participant.cl_type
        el_type = participant.el_type

        node_selectors = ethereum_package_input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )

        el_tolerations = ethereum_package_input_parser.get_client_tolerations(
            participant.el_tolerations, participant.tolerations, global_tolerations
        )

        cl_tolerations = ethereum_package_input_parser.get_client_tolerations(
            participant.cl_tolerations, participant.tolerations, global_tolerations
        )

        if el_type not in el_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    el_type, ",".join(el_launchers.keys())
                )
            )
        if cl_type not in cl_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    cl_type, ",".join(cl_launchers.keys())
                )
            )

        el_launcher, el_launch_method = (
            el_launchers[el_type]["launcher"],
            el_launchers[el_type]["launch_method"],
        )

        cl_launcher, cl_launch_method = (
            cl_launchers[cl_type]["launcher"],
            cl_launchers[cl_type]["launch_method"],
        )

        # Zero-pad the index using the calculated zfill value
        index_str = ethereum_package_shared_utils.zfill_custom(
            index + 1, len(str(len(participants)))
        )

        el_service_name = "{0}-el-{1}-{2}-{3}-{4}".format(
            participant.service_name_prefix, index_str, el_type, cl_type, l2_services_suffix
        )
        cl_service_name = "{0}-cl-{1}-{2}-{3}-{4}".format(
            participant.service_name_prefix, index_str, cl_type, el_type, l2_services_suffix
        )

        sequencer_context = all_cl_contexts[0] if len(all_cl_contexts) > 0 else None
        el_context = el_launch_method(
            plan,
            el_launcher,
            el_service_name,
            participant,
            global_log_level,
            persistent,
            el_tolerations,
            node_selectors,
            all_el_contexts,
            sequencer_enabled,
            sequencer_context,
        )
        all_el_contexts.append(el_context)

        new_el_context = None
        if "builder-op" in cl_service_name:
            plan.print("Launching rollup-boost")

            sequencer_el_context = all_el_contexts[0] # currently by default first EL is sequencer
            plan.print(sequencer_el_context)
            builder_el_context = get_builder_el_context(plan, all_el_contexts)
            plan.print(builder_el_context)

            rollup_boost_service = rollup_boost.launch(
                plan,
                sequencer_el_context,
                builder_el_context,
                jwt_file,
            )
            plan.print(rollup_boost_service)
            new_el_context = ethereum_package_el_context.new_el_context(
                client_name=el_context.client_name,
                enode=el_context.enode,
                ip_addr=rollup_boost_service.ip_address,
                rpc_port_num=el_context.rpc_port_num,
                ws_port_num=el_context.ws_port_num,
                engine_rpc_port_num=8081,
                rpc_http_url=el_context.rpc_http_url,
                enr=el_context.enr,
                service_name=el_context.service_name,
                el_metrics_info=el_context.el_metrics_info,
            )
            plan.print(new_el_context)

        cl_context = cl_launch_method(
            plan,
            cl_launcher,
            cl_service_name,
            participant,
            global_log_level,
            persistent,
            cl_tolerations,
            node_selectors,
            new_el_context if new_el_context else el_context,
            all_cl_contexts,
            l1_config_env_vars,
            sequencer_enabled,
        )

        sequencer_enabled = False

        all_cl_contexts.append(cl_context)

    plan.print("Successfully added {0} EL/CL participants".format(num_participants))
    return all_el_contexts, all_cl_contexts


def get_builder_el_context(
    plan,
    all_el_contexts,
):
    for el_context in all_el_contexts:
        if "builder" in el_context.service_name:
            return el_context

    fail("No builder EL context found")
