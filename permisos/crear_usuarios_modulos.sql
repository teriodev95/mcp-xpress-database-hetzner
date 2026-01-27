-- ============================================
-- TABLA: usuarios_modulos
-- Relación directa usuario → módulo
-- ============================================

CREATE TABLE IF NOT EXISTS usuarios_modulos (
    usuario_id INT NOT NULL,
    modulo_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (usuario_id, modulo_id),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(UsuarioID) ON DELETE CASCADE,
    FOREIGN KEY (modulo_id) REFERENCES modulos(id) ON DELETE CASCADE
);

-- ============================================
-- JEFE DE ADMIN: todo menos rh
-- ============================================
INSERT INTO usuarios_modulos (usuario_id, modulo_id)
SELECT u.UsuarioID, m.id
FROM usuarios u
CROSS JOIN modulos m
WHERE u.Tipo = 'Jefe de Admin'
AND u.Status = 1
AND m.nombre != 'rh'
AND m.plataforma_id = 1;

-- ============================================
-- OFICINA: cobranza + prestamos
-- ============================================
INSERT INTO usuarios_modulos (usuario_id, modulo_id)
SELECT u.UsuarioID, m.id
FROM usuarios u
CROSS JOIN modulos m
WHERE u.Tipo = 'Oficina'
AND u.Status = 1
AND m.plataforma_id = 1
AND m.nombre IN ('dashboard','cobranza','desglose','resumen-ventas',
                 'resumen-asignaciones','flujo-efectivo','detalles-cierre',
                 'solicitudes','prestamos');

-- ============================================
-- RH: solo rh
-- ============================================
INSERT INTO usuarios_modulos (usuario_id, modulo_id)
SELECT u.UsuarioID, m.id
FROM usuarios u
CROSS JOIN modulos m
WHERE u.Tipo = 'RH'
AND u.Status = 1
AND m.plataforma_id = 1
AND m.nombre = 'rh';

-- ============================================
-- SISTEMAS: todo
-- ============================================
INSERT INTO usuarios_modulos (usuario_id, modulo_id)
SELECT u.UsuarioID, m.id
FROM usuarios u
CROSS JOIN modulos m
WHERE u.Tipo = 'Sistemas'
AND u.Status = 1
AND m.plataforma_id = 1;

-- ============================================
-- HANNIA RACHELL (727): solo rh
-- ============================================
INSERT INTO usuarios_modulos (usuario_id, modulo_id)
SELECT 727, id FROM modulos WHERE nombre = 'rh' AND plataforma_id = 1;
