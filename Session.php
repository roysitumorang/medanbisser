<?php

class Session {
	private $_db;

	public function __construct(PDO $db) {
		$this->_db = $db;
		session_set_save_handler(
			[$this, 'open']
			, [$this, 'close']
			, [$this, 'read']
			, [$this, 'write']
			, [$this, 'destroy']
			, [$this, 'gc']
		);
	}

	public function open() { return true; }

	public function close() { return true; }

	public function read($id) {
		return base64_decode($this->_db->query("SELECT data FROM sessions WHERE id = '$id'")->fetchColumn());
	}

	public function write($id, $data) {
		$stmt = $this->_db->prepare('INSERT INTO sessions (id, user_id, ip, data, last_modified) VALUES (:id, :user_id, :ip, :data, :last_modified) ON CONFLICT (id) DO UPDATE SET user_id = :user_id, ip = :ip, data = :data, last_modified = :last_modified');
		return $stmt->execute([
			':id'            => $id,
			':user_id'       => igbinary_unserialize($data)['user_id'],
			':ip'            => Utilities::get_real_ip_address(),
			':data'          => base64_encode($data),
			':last_modified' => time(),
		]);
	}

	public function destroy($id) {
		return $this->_db->prepare('DELETE FROM sessions WHERE id = ?')->execute([$id]);
	}

	public function gc($max) {
		return $this->_db->prepare('DELETE FROM sessions WHERE last_modified + ? < ?')->execute([$max, time()]);
	}
}