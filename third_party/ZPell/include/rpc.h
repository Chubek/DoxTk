#ifndef ZPELL_RPC_H
#define ZPELL_RPC_H

#include <string>
#include <memory>

namespace zpell {

class ZPell;

/**
 * @brief JSON-RPC server
 */
class RPCServer {
public:
    RPCServer();
    ~RPCServer();
    
    /**
     * @brief Initialize RPC server
     * @param zpell ZPell instance
     * @param host Host address
     * @param port Port number
     * @return True if successful
     */
    bool initialize(ZPell* zpell, const std::string& host, int port);
    
    /**
     * @brief Start server (blocking)
     */
    void run();
    
    /**
     * @brief Stop server
     */
    void stop();
    
    /**
     * @brief Check if server is running
     * @return True if running
     */
    bool is_running() const { return running_; }
    
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
    ZPell* zpell_ = nullptr;
    bool running_ = false;
};

} // namespace zpell

#endif // ZPELL_RPC_H
