import "@openzeppelin/contracts/access/Ownable.sol";
contract AddressBook is Ownable {
    mapping(string => address) private addresses;
    constructor(address initialOwner) Ownable(initialOwner) {}
    function addAddress(string memory name, address addr) external onlyOwner {
        addresses[name] = addr;
    }
    function getAddress(string memory name) external view returns (address) {
        return addresses[name];
    }
}