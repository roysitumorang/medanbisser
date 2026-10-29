<?php

class Session implements SessionHandlerInterface, SessionIdInterface {
	function __construct(private PDO $_db) {
		// The callable-list form of session_set_save_handler() is deprecated since PHP 8.4.
		// Session writing is flushed by the shutdown function registered in index.php.
		session_set_save_handler($this, false);
	}

	function open(string $path, string $name): bool { return true; }

	function close(): bool { return true; }

	function read(string $id): string|false {
		$stmt = $this->_db->prepare('SELECT data FROM sessions WHERE id = ?');
		$stmt->execute([$id]);
		return (string) $stmt->fetchColumn();
	}

	function write(string $id, string $data): bool {
		$stmt = $this->_db->prepare('INSERT INTO sessions (id, user_id, ip, data, last_modified) VALUES (:id, :user_id, :ip, :data, :last_modified) ON CONFLICT (id) DO UPDATE SET user_id = :user_id, ip = :ip, data = :data, last_modified = :last_modified');
		return $stmt->execute([
			':id'            => $id,
			':user_id'       => $_SESSION['user_id'] ?? null,
			':ip'            => Utilities::get_real_ip_address(),
			':data'          => $data,
			':last_modified' => time(),
		]);
	}

	function destroy(string $id): bool {
		return $this->_db->prepare('DELETE FROM sessions WHERE id = ?')->execute([$id]);
	}

	function gc(int $max_lifetime): int|false {
		$stmt = $this->_db->prepare('DELETE FROM sessions WHERE last_modified + ? < ?');
		return $stmt->execute([$max_lifetime, time()]) ? $stmt->rowCount() : false;
	}

	function create_sid(): string {
		return bin2hex(random_bytes(16));
	}
}
