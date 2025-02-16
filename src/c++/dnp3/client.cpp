#include <functional>
#include <thread>

#include "client.hpp"

#include "opendnp3/ConsoleLogger.h"
#include "opendnp3/master/DefaultMasterApplication.h"

namespace otsim {
namespace dnp3 {

Client::Client() {
    manager.reset(new opendnp3::DNP3Manager(std::thread::hardware_concurrency(), opendnp3::ConsoleLogger::Create()));
}

bool Client::Init(const std::string& id, const std::string& endpoint) {
    std::string ip = endpoint.substr(0, endpoint.find(":"));
    std::uint16_t port = static_cast<std::uint16_t>(stoi((endpoint.substr(endpoint.find(":") + 1))));

    try {
        channel = manager->AddTCPClient(
            id,
            opendnp3::levels::NORMAL,
            opendnp3::ChannelRetry::Default(),
            std::vector<opendnp3::IPEndpoint>{opendnp3::IPEndpoint(ip, port)},
            "0.0.0.0",
            nullptr
        );
    } catch (std::exception& e) {
        std::cout << "Failed to add TCPClient due to the error: " << std::string(e.what());
        return false;
    }

    return true;
}

std::shared_ptr<Master> Client::AddMaster(std::string id, std::uint16_t local, std::uint16_t remote, std::int64_t timeout, Pusher pusher) {
    std::cout << "adding master " << local << " --> " << remote << std::endl;

    auto master = Master::Create(id, pusher);
    auto config = master->BuildConfig(local, remote, timeout);

    auto iMaster = channel->AddMaster(id, master, opendnp3::DefaultMasterApplication::Create(), config);

    master->SetIMaster(iMaster);
    masters[remote] = master;

    return master;
}

void Client::Start() {
    for (const auto& kv : masters) {
        std::cout << "enabling master to " << kv.first << std::endl;

        kv.second->Enable();
    }
}

void Client::Stop() {
    for (const auto& kv : masters) {
        std::cout << "disabling master to " << kv.first << std::endl;

        kv.second->Disable();
    }
}

} // namespace dnp3
} // namespace otsim
