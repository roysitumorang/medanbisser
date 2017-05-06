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
		$stmt = $this->_db->prepare('WITH upsert AS (UPDATE sessions SET user_id = :user_id, ip = :ip, data = :data, last_modified = :last_modified WHERE id = :id RETURNING 1) INSERT INTO sessions (id, user_id, ip, data, last_modified) SELECT :id, :user_id, :ip, :data, :last_modified WHERE NOT EXISTS(SELECT 1 FROM upsert)');
		foreach ([[':id', $id, PDO::PARAM_STR]
			, [':user_id', igbinary_unserialize($data)['user_id'], PDO::PARAM_INT]
			, [':ip', Utilities::get_real_ip_address(), PDO::PARAM_STR]
			, [':data', base64_encode($data), PDO::PARAM_LOB]
			, [':last_modified', time(), PDO::PARAM_INT]] as $arg) {
			call_user_func_array([$stmt, 'bindValue'], $arg);
		}
		return $stmt->execute();
	}

	public function destroy($id) {
		return $this->_db->prepare('DELETE FROM sessions WHERE id = ?')->execute([$id]);
	}

	public function gc($max) {
		return $this->_db->prepare('DELETE FROM sessions WHERE last_modified + ? < ?')->execute([$max, time()]);
	}
}