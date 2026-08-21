#ifndef ZPELL_IPC_H
#define ZPELL_IPC_H

#include <string>
#include <memory>
#include <vector>

namespace zpell {

class ZPell;

/**
 * @brief IPC message structure
 */
struct IPCMessage {
    enum class Type {
        CHECK_WORD,
        SUGGEST,
        RELOAD,
        RESPONSE
    };
    
    Type type;
    std::string data;
    std::vector<std::string> results;
};

/**
 * @brief IPC server using shared memory
 */
class IPCServer {
public:
    IPCServer();
    ~IPCServer();
    
    /**
     * @brief Initialize IPC server
     * @param zpell ZPell instance
     * @param name Shared memory name
     * @return True if successful
     */
    bool initialize(ZPell* zpell, const std::string& name);
    
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

#endif // ZPELL_IPC_H
