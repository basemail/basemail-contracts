// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {ERC721} from "dependencies/solady-0.0.201/src/tokens/ERC721.sol";

contract BasemailAccount is ERC721 {
    // ========== ERRORS ========== //

    error AccountAlreadyExists();
    error AccountDoesNotExist();
    error OnlyTokenHolder();
    error UsernameInvalid();

    // ========== EVENTS ========== //

    event AccountCreated(uint256 accountId, address to, string username);
    event AccountDeleted(uint256 accountId);
    event UsernameChanged(uint256 accountId, string oldUsername, string newUsername);

    // ========== STATE VARIABLES ========== //

    string constant DOMAIN = "basechain.email";
    uint256 public idCounter;
    mapping(bytes32 username => uint256 accountId) public nameToId;
    mapping(uint256 accountId => bytes32 username) public idToName;
    mapping(address holder => uint256[] accounts) public holderAccounts;

    // ========== CONSTRUCTOR ========== //

    constructor() {
        idCounter = 1; // start at 1 since 0 is reserved for non-existent accounts
    }

    // ========== ACCOUNT MANAGEMENT ========== //

    function createAccount(address to_, string calldata username_) external {
        // Validate username
        bytes32 username = _validateNewUsername(username_);

        // Create the account
        _createAccount(to_, username, username_);
    }

    function _createAccount(address to_, bytes32 username_, string calldata usernameStr_) internal {
        // Get the token ID for the account
        uint256 accountId = idCounter++;

        // Create the account and set the recipient as the owner
        _safeMint(to_, accountId);

        // Set the account info
        idToName[accountId] = username_;
        nameToId[username_] = accountId;

        // Emit the account creation event
        emit AccountCreated(accountId, to_, usernameStr_);
    }

    function deleteAccount(uint256 accountId_) external {
        // Account must exist
        if (accountId_ >= idCounter || !_exists(accountId_)) revert AccountDoesNotExist();

        // Caller must be the holder of the account
        _onlyAccountHolder(accountId_);

        // Delete the account
        _burn(accountId_);

        // Get the account's username
        bytes32 username = idToName[accountId_];

        // Clear the account info and remove the username mapping
        delete idToName[accountId_];
        delete nameToId[username];

        // Emit the account deletion event
        emit AccountDeleted(accountId_);
    }

    function changeUsername(string calldata oldUsername_, string calldata newUsername_) external {
        // Validate the old username
        bytes32 oldUsername = _validateExistingUsername(oldUsername_);

        // Get the account ID
        uint256 accountId = nameToId[oldUsername];

        // Caller must be the holder of the account
        _onlyAccountHolder(accountId);

        // Validate the new username
        bytes32 newUsername = _validateNewUsername(newUsername_);

        // Change the account's username
        _changeUsername(accountId, oldUsername, oldUsername_, newUsername, newUsername_);
    }

    function _changeUsername(
        uint256 accountId_,
        bytes32 oldUsername_,
        string calldata oldUsernameStr_,
        bytes32 newUsername_,
        string calldata newUsernameStr_
    ) internal {
        // Update the account info
        idToName[accountId_] = newUsername_;

        // Update the username mapping
        delete nameToId[oldUsername_];
        nameToId[newUsername_] = accountId_;

        // Emit the username change event
        emit UsernameChanged(accountId_, oldUsernameStr_, newUsernameStr_);
    }

    function transferUsername(address to_, string calldata usernameToTransfer_, string calldata newUsername_)
        external
    {
        // Validate the username to transfer
        bytes32 usernameToTransfer = _validateExistingUsername(usernameToTransfer_);

        // Get the account ID
        uint256 accountId = nameToId[usernameToTransfer];

        // Caller must be the holder of the account
        _onlyAccountHolder(accountId);

        // Validate the new username
        bytes32 newUsername = _validateNewUsername(newUsername_);

        // Change the username of the current account
        // This makes the username to transfer available for the new holder
        _changeUsername(accountId, usernameToTransfer, usernameToTransfer_, newUsername, newUsername_);

        // Create a new account for the recipient with the transferred username
        _createAccount(to_, usernameToTransfer, usernameToTransfer_);
    }

    // ========== ACCOUNT INFORMATION =========== //

    function getAccounts(address holder_) external view returns (uint256[] memory) {
        return holderAccounts[holder_];
    }

    function getAccountId(string calldata username_) external view returns (uint256) {
        return nameToId[_validateExistingUsername(username_)];
    }

    function getUsernames(address holder_) external view returns (string[] memory) {
        uint256[] memory accountIds = holderAccounts[holder_];
        uint256 len = accountIds.length;
        string[] memory usernames = new string[](len);
        for (uint256 i = 0; i < len; i++) {
            usernames[i] = _bytes32ToStr(idToName[accountIds[i]]);
        }
        return usernames;
    }

    function getUsername(uint256 accountId_) external view returns (string memory) {
        if (accountId_ >= idCounter || !_exists(accountId_)) revert AccountDoesNotExist();
        return _bytes32ToStr(idToName[accountId_]);
    }

    function _bytes32ToStr(bytes32 x_) internal pure returns (string memory) {
        bytes memory byteString = abi.encodePacked(x_);

        // Iterate over the bytes until we find a zero byte
        // Given our string validation during username creation.
        // we know this is the end of the name
        uint256 length = 0;
        while (byteString[length] != 0) {
            length++;
        }

        // Create a new bytes memory and copy the bytes into it
        bytes memory bytesArray = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            bytesArray[i] = byteString[i];
        }

        return string(bytesArray);
    }

    // ========== INTERNAL HELPER FUNCTIONS ========== //

    function _validateNewUsername(string calldata username_) internal view returns (bytes32) {
        // If the username is longer than 32 bytes, revert
        bytes memory usernameBytes = bytes(username_);
        uint256 len = usernameBytes.length;
        if (len > 32 || len < 3) revert UsernameInvalid();

        // We allow the following characters in the username: a-z, A-Z, 0-9, ., -, _
        // We also require that the username starts with a letter or number
        // and ends with a letter or number
        for (uint256 i; i < len; i++) {
            bytes1 char = usernameBytes[i];
            // If the username doesn't start and end with a letter or number, revert
            if (i == 0 || i == len - 1) {
                if (
                    !(char >= 0x30 && char <= 0x39) // 0-9
                        && !(char >= 0x41 && char <= 0x5A) // A-Z
                        && !(char >= 0x61 && char <= 0x7A) // a-z
                ) revert UsernameInvalid();
            }
            // Otherwise, check if the character is valid
            else {
                if (
                    !(char >= 0x30 && char <= 0x39) // 0-9
                        && !(char >= 0x41 && char <= 0x5A) // A-Z
                        && !(char >= 0x61 && char <= 0x7A) // a-z
                        && !(char == 0x2E) // .
                        && !(char == 0x2D) // -
                        && !(char == 0x5F) // _
                ) revert UsernameInvalid();
            }
        }

        bytes32 username = bytes32(usernameBytes);

        // If the username has already been taken, revert
        if (nameToId[username] != 0) revert AccountAlreadyExists();

        return username;
    }

    function _validateExistingUsername(string calldata username_) internal view returns (bytes32) {
        bytes32 username = bytes32(bytes(username_));

        // If the username has not been taken, revert
        if (nameToId[username] == 0) revert AccountDoesNotExist();

        return username;
    }

    function _onlyAccountHolder(uint256 accountId_) internal view {
        // Caller must be the holder of the account
        if (ownerOf(accountId_) != msg.sender) revert OnlyTokenHolder();
    }

    // ========== ERC721 METADATA ========== //

    function name() public pure override returns (string memory) {
        return "Basemail";
    }

    function symbol() public pure override returns (string memory) {
        return "BMAIL";
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        // TODO - Implement token URI
        return "";
    }

    // ========== ERC721 OVERRIDES ========== //

    // We modify transfers (including mints and burns) to update the holderAccounts mapping
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        // Remove the accounts from the existing holder's accounts array
        if (from != address(0)) {
            uint256[] storage fromAccounts = holderAccounts[from];
            uint256 len = fromAccounts.length;
            for (uint256 i = 0; i < len; i++) {
                if (fromAccounts[i] == tokenId) {
                    fromAccounts[i] = fromAccounts[len - 1];
                    fromAccounts.pop();
                    break;
                }
            }
        }

        // Add to the new holder's accounts array
        if (to != address(0)) {
            holderAccounts[to].push(tokenId);
        }
    }
}
