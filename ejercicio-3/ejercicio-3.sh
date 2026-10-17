#!/usr/bin/env bash

# Archivos de base de datos y logs
declare -r DB_FILE="data.sq3"
declare -r SYS_LOG="system.log"
declare -r ERR_LOG="error.log"

# Menú principal
declare -r -i OPCION_ALTA=1
declare -r -i OPCION_BAJA=2
declare -r -i OPCION_EDITAR=3
declare -r -i OPCION_MOSTRAR=4
declare -r -i OPCION_HTML=5
declare -r -i OPCION_SALIR=6


USUARIO_ACTUAL="Invitado"
ID_USER_ACTUAL=0

#
registrar_sistema() {
    local accion="$1"
    local fecha
    fecha=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s\t%s\t%s\t%s\n" "$fecha" "$ID_USER_ACTUAL" "$USUARIO_ACTUAL" "$accion" >> "$SYS_LOG"
}

registrar_error() {
    local mensaje="$1"
    local fecha
    fecha=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s\tERROR:\t%s\n" "$fecha" "$mensaje" >> "$ERR_LOG"
}

inicializar_bd() {
    if [[ ! -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" <<EOF
CREATE TABLE usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL
);

CREATE TABLE productos (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio REAL NOT NULL
);
EOF
        registrar_sistema "Base de datos creada e inicializada."
    fi
}

bienvenida() {
    printf "Bienvenido/a al sistema\n\n"
}

# --- AUTENTICACIÓN Y USUARIOS (SQL) ---
registrar_usuario() {
    declare usuario=""
    declare clave=""
    declare pass_hash=""

    printf "\n=== REGISTRO DE USUARIO ===\n"
    read -rp "Ingrese nombre de usuario: " usuario

    if [[ -z "$usuario" ]]; then
        registrar_error "Intento de registro con usuario vacío."
        printf "Error: El usuario no puede estar vacío.\n"
        return 1
    fi

 
    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM usuarios WHERE username='$usuario';")
    if [[ "$existe" -gt 0 ]]; then
        registrar_error "Intento de registrar usuario duplicado: $usuario"
        printf "Error: El usuario '%s' ya existe.\n" "$usuario"
        return 1
    fi

    read -rsp "Ingrese contraseña: " clave
    printf "\n"

    if [[ -z "$clave" ]]; then
        registrar_error "Intento de registro con contraseña vacía para el usuario: $usuario"
        printf "Error: La contraseña no puede estar vacía.\n"
        return 1
    fi

    pass_hash=$(echo -n "$clave" | sha256sum | awk '{print $1}')

    sqlite3 "$DB_FILE" "INSERT INTO usuarios (username, password_hash) VALUES ('$usuario', '$pass_hash');"
    registrar_sistema "Usuario registrado exitosamente: $usuario"
    printf "Usuario '%s' registrado con éxito.\n" "$usuario"
}

iniciar_sesion() {
    declare usuario=""
    declare clave=""
    declare pass_hash=""

    printf "\n=== INICIAR SESIÓN ===\n"
    read -rp "Usuario: " usuario
    read -rsp "Contraseña: " clave
    printf "\n"

    pass_hash=$(echo -n "$clave" | sha256sum | awk '{print $1}')

    local user_id
    user_id=$(sqlite3 "$DB_FILE" "SELECT id FROM usuarios WHERE username='$usuario' AND password_hash='$pass_hash';")

    if [[ -n "$user_id" ]]; then
        USUARIO_ACTUAL="$usuario"
        ID_USER_ACTUAL="$user_id"
        registrar_sistema "Inicio de sesión exitoso."
        printf "Acceso concedido. ¡Bienvenido/a %s!\n" "$usuario"
        return 0
    else
        registrar_error "Fallo de inicio de sesión para el usuario: $usuario"
        printf "Error: Usuario o contraseña incorrectos.\n"
        return 1
    fi
}

menu_autenticacion() {
    declare opcion=0

    while true; do
        printf "\nAUTENTICACIÓN:\n"
        printf "1. Iniciar sesión\n"
        printf "2. Registrar usuario\n"
        printf "3. Salir\n"
        read -rp "Opción: " opcion

        case $opcion in
            1)
                if iniciar_sesion; then
                    return 0
                fi
                ;;
            2)
                registrar_usuario
                ;;
            3)
                registrar_sistema "Salida del sistema desde autenticación."
                return 1
                ;;
            *)
                registrar_error "Opción inválida en menú de autenticación."
                printf "Opción inválida.\n"
                ;;
        esac
    done
}

# --- OPERACIONES CON PRODUCTOS ---
alta() {
    declare id=""
    declare nombre=""
    declare precio=""

    printf "\n=== ALTA DE PRODUCTO ===\n"
    read -rp "Ingrese ID: " id
    
    if [[ -z "$id" ]]; then
        registrar_error "Alta de producto fallida: ID vacío."
        printf "Error: El ID no puede estar vacío.\n"
        return
    fi

    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id='$id';")
    if [[ "$existe" -gt 0 ]]; then
        registrar_error "Intento de agregar producto duplicado ID: $id"
        printf "Error: Ya existe un producto con el ID '%s'.\n" "$id"
        return
    fi

    read -rp "Ingrese Nombre: " nombre
    read -rp "Ingrese Precio: " precio

    sqlite3 "$DB_FILE" "INSERT INTO productos (id, nombre, precio) VALUES ('$id', '$nombre', $precio);"
    registrar_sistema "Alta de producto exitosa (ID: $id, Nombre: $nombre)"
    printf "Producto '%s' guardado exitosamente.\n" "$id"
}

baja() {
    declare id=""

    printf "\n=== BAJA DE PRODUCTO ===\n"
    read -rp "Ingrese ID del producto a eliminar: " id

    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id='$id';")
    if [[ "$existe" -eq 0 ]]; then
        registrar_error "Intento de dar de baja producto inexistente ID: $id"
        printf "Error: El producto con ID '%s' no existe.\n" "$id"
        return
    fi

    sqlite3 "$DB_FILE" "DELETE FROM productos WHERE id='$id';"
    registrar_sistema "Baja de producto exitosa (ID: $id)"
    printf "Producto con ID '%s' eliminado.\n" "$id"
}

editar() {
    declare id_buscar=""
    declare nuevo_nombre=""
    declare nuevo_precio=""

    printf "\n=== EDITAR PRODUCTO ===\n"
    read -rp "Ingrese ID del producto a editar: " id_buscar

    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id='$id_buscar';")
    if [[ "$existe" -eq 0 ]]; then
        registrar_error "Intento de editar producto inexistente ID: $id_buscar"
        printf "Error: El producto con ID '%s' no existe.\n" "$id_buscar"
        return
    fi

    read -rp "Ingrese nuevo Nombre: " nuevo_nombre
    read -rp "Ingrese nuevo Precio: " nuevo_precio

    sqlite3 "$DB_FILE" "UPDATE productos SET nombre='$nuevo_nombre', precio=$nuevo_precio WHERE id='$id_buscar';"
    registrar_sistema "Edición de producto exitosa (ID: $id_buscar)"
    printf "Producto '%s' actualizado correctamente.\n" "$id_buscar"
}

mostrar() {
    printf "\nLISTADO DE PRODUCTOS:\n"
    
    local total
    total=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos;")
    if [[ "$total" -eq 0 ]]; then
        printf "No hay productos registrados en la base de datos.\n"
        registrar_sistema "Consulta de inventario vacía."
        return
    fi

    printf "==================================================\n"
    printf "%-10s | %-20s | %-10s\n" "ID" "NOMBRE" "PRECIO"
    printf "==================================================\n"

    sqlite3 -separator $'\t' "$DB_FILE" "SELECT id, nombre, precio FROM productos;" | while IFS=$'\t' read -r col_id col_nombre col_precio; do
        printf "%-10s | %-20s | $%-10.2f\n" "$col_id" "$col_nombre" "$col_precio"
    done
    
    printf "==================================================\n"
    registrar_sistema "Consulta de inventario realizada con éxito."
}

generar_reporte_html() {
    declare -r html_out="productos.html"
    printf "\nGenerando reporte 'productos.html'...\n"

    cat << EOF > "$html_out"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Reporte de Productos</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 30px; }
        h1 { color: #2c3e50; }
        table { border-collapse: collapse; width: 100%; margin-top: 15px; }
        th, td { border: 1px solid #bdc3c7; padding: 10px; text-align: left; }
        th { background-color: #34495e; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Reporte General de Productos (Base de Datos)</h1>
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Nombre</th>
                <th>Precio</th>
            </tr>
        </thead>
        <tbody>
EOF

    sqlite3 -separator $'\t' "$DB_FILE" "SELECT id, nombre, precio FROM productos;" | while IFS=$'\t' read -r col_id col_nombre col_precio; do
        printf "            <tr><td>%s</td><td>%s</td><td>$%.2f</td></tr>\n" "$col_id" "$col_nombre" "$col_precio" >> "$html_out"
    done

    cat << EOF >> "$html_out"
        </tbody>
    </table>
</body>
</html>
EOF

    registrar_sistema "Generación de reporte HTML exitosa."
    printf "Reporte '%s' generado con éxito.\n" "$html_out"
}

# --- FLUJO PRINCIPAL ---
main() {
    inicializar_bd
    bienvenida

    if ! menu_autenticacion; then
        printf "\nSaliendo del sistema...\n"
        return 0
    fi

    declare opcion=0

    while [[ "$opcion" -ne "$OPCION_SALIR" ]]; do
        printf "\nACCIONES:\n"
        printf "1. Alta producto\n"
        printf "2. Baja producto\n"
        printf "3. Editar producto\n"
        printf "4. Mostrar inventario\n"
        printf "5. Generar reporte HTML\n"
        printf "6. Salir\n"
        read -rp "Opción: " opcion

        case $opcion in
            $OPCION_ALTA)
                alta
                ;;
            $OPCION_BAJA)
                baja
                ;;
            $OPCION_EDITAR)
                editar
                ;;
            $OPCION_MOSTRAR)
                mostrar
                ;;
            $OPCION_HTML)
                generar_reporte_html
                ;;
            $OPCION_SALIR)
                registrar_sistema "Cierre de sesión del usuario."
                printf "\nSaliendo del programa...\n"
                ;;
            *)
                registrar_error "Opción de menú principal inválida: $opcion"
                printf "\nOpción inválida.\n"
                ;;
        esac
    done

    return 0
}

main
