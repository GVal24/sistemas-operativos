#!/usr/bin/env bash

# Archivos de base de datos y logs
declare -r DB_FILE="data.sq3"
declare -r SYS_LOG="system.log"
declare -r ERR_LOG="error.log"

# Variables globales de sesión
USUARIO_ACTUAL="Invitado"
ID_USER_ACTUAL=0

# --- FUNCIONES DE LOGS Y UTILIDADES ---
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

# --- AUTENTICACIÓN Y USUARIOS (Whiptail) ---
registrar_usuario() {
    local usuario=""
    local clave=""

    usuario=$(whiptail --title "Registro de Usuario" --inputbox "Ingrese nombre de usuario:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$usuario" ]]; then
        return
    fi

    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM usuarios WHERE username='$usuario';")
    if [[ "$existe" -gt 0 ]]; then
        whiptail --title "Error" --msgbox "El usuario '$usuario' ya existe." 6 40
        return
    fi

    clave=$(whiptail --title "Registro de Usuario" --passwordbox "Ingrese contraseña:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$clave" ]]; then
        whiptail --title "Error" --msgbox "La contraseña no puede estar vacía." 6 40
        return
    fi

    local pass_hash
    pass_hash=$(echo -n "$clave" | sha256sum | awk '{print $1}')

    sqlite3 "$DB_FILE" "INSERT INTO usuarios (username, password_hash) VALUES ('$usuario', '$pass_hash');"
    registrar_sistema "Usuario registrado exitosamente: $usuario"
    whiptail --title "Éxito" --msgbox "¡Usuario registrado con éxito!" 6 40
}

iniciar_sesion() {
    local usuario=""
    local clave=""

    usuario=$(whiptail --title "Iniciar Sesión" --inputbox "Usuario:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$usuario" ]]; then
        return 1
    fi

    clave=$(whiptail --title "Iniciar Sesión" --passwordbox "Contraseña:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$clave" ]]; then
        return 1
    fi

    local pass_hash
    pass_hash=$(echo -n "$clave" | sha256sum | awk '{print $1}')

    local user_id
    user_id=$(sqlite3 "$DB_FILE" "SELECT id FROM usuarios WHERE username='$usuario' AND password_hash='$pass_hash';")

    if [[ -n "$user_id" ]]; then
        USUARIO_ACTUAL="$usuario"
        ID_USER_ACTUAL="$user_id"
        registrar_sistema "Inicio de sesión exitoso."
        return 0
    else
        registrar_error "Fallo de inicio de sesión para el usuario: $usuario"
        whiptail --title "Error" --msgbox "Usuario o contraseña incorrectos." 6 40
        return 1
    fi
}

menu_autenticacion() {
    while true; do
        local opcion
        opcion=$(whiptail --title "Sistema de Autenticación" \
                          --menu "Seleccione una opción:" 12 45 3 \
                          "1" "Iniciar sesión" \
                          "2" "Registrar usuario" \
                          "3" "Salir" \
                          3>&1 1>&2 2>&3)

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
                return 1
                ;;
        esac
    done
}

# --- OPERACIONES CON PRODUCTOS (Whiptail) ---
alta() {
    local id=""
    local nombre=""
    local precio=""

    id=$(whiptail --title "Alta de Producto" --inputbox "Ingrese ID del producto:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$id" ]]; then
        return
    fi

    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id='$id';")
    if [[ "$existe" -gt 0 ]]; then
        registrar_error "Intento de agregar producto duplicado ID: $id"
        whiptail --title "Error" --msgbox "Ya existe un producto con el ID '$id'." 6 45
        return
    fi

    nombre=$(whiptail --title "Alta de Producto" --inputbox "Ingrese Nombre del producto:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$nombre" ]]; then
        return
    fi

    precio=$(whiptail --title "Alta de Producto" --inputbox "Ingrese Precio del producto:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$precio" ]]; then
        return
    fi

    sqlite3 "$DB_FILE" "INSERT INTO productos (id, nombre, precio) VALUES ('$id', '$nombre', $precio);"
    registrar_sistema "Alta de producto exitosa (ID: $id, Nombre: $nombre)"
    whiptail --title "Éxito" --msgbox "¡Producto guardado exitosamente!" 6 40
}

baja() {
    local id
    id=$(whiptail --title "Baja de Producto" --inputbox "Ingrese el ID del producto a eliminar:" 8 45 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 || -z "$id" ]]; then
        return
    fi

    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id='$id';")
    if [[ "$existe" -eq 0 ]]; then
        registrar_error "Intento de dar de baja producto inexistente ID: $id"
        whiptail --title "Error" --msgbox "El producto con ID '$id' no existe." 6 40
        return
    fi

    sqlite3 "$DB_FILE" "DELETE FROM productos WHERE id='$id';"
    registrar_sistema "Baja de producto exitosa (ID: $id)"
    whiptail --title "Éxito" --msgbox "¡Producto eliminado con éxito!" 6 40
}

editar() {
    local id_buscar
    id_buscar=$(whiptail --title "Editar Producto" --inputbox "Ingrese el ID del producto a editar:" 8 45 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 || -z "$id_buscar" ]]; then
        return
    fi

    local existe
    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id='$id_buscar';")
    if [[ "$existe" -eq 0 ]]; then
        registrar_error "Intento de editar producto inexistente ID: $id_buscar"
        whiptail --title "Error" --msgbox "El producto con ID '$id_buscar' no existe." 6 40
        return
    fi

    local nuevo_nombre
    local nuevo_precio

    nuevo_nombre=$(whiptail --title "Editar Producto" --inputbox "Ingrese nuevo Nombre:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$nuevo_nombre" ]]; then
        return
    fi

    nuevo_precio=$(whiptail --title "Editar Producto" --inputbox "Ingrese nuevo Precio:" 8 45 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || -z "$nuevo_precio" ]]; then
        return
    fi

    sqlite3 "$DB_FILE" "UPDATE productos SET nombre='$nuevo_nombre', precio=$nuevo_precio WHERE id='$id_buscar';"
    registrar_sistema "Edición de producto exitosa (ID: $id_buscar)"
    whiptail --title "Éxito" --msgbox "¡Producto actualizado correctamente!" 6 40
}

mostrar() {
    local total
    total=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos;")
    if [[ "$total" -eq 0 ]]; then
        whiptail --title "Inventario" --msgbox "No hay productos registrados en la base de datos." 6 45
        registrar_sistema "Consulta de inventario vacía."
        return
    fi

    local listado=""
    while IFS=$'\t' read -r col_id col_nombre col_precio; do
        listado+="$col_id | $col_nombre | \$$col_precio\n"
    done < <(sqlite3 -separator $'\t' "$DB_FILE" "SELECT id, nombre, precio FROM productos;")

    whiptail --title "Listado de Productos" --msgbox "$listado" 15 50
    registrar_sistema "Consulta de inventario realizada con éxito."
}

generar_reporte_html() {
    declare -r html_out="productos.html"

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
    <h1>Reporte General de Productos (TUI / Base de Datos)</h1>
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
        printf "            <tr><td>%s</td><td>%s</td><td>\$%.2f</td></tr>\n" "$col_id" "$col_nombre" "$col_precio" >> "$html_out"
    done

    cat << EOF >> "$html_out"
        </tbody>
    </table>
</body>
</html>
EOF

    registrar_sistema "Generación de reporte HTML exitosa."
    whiptail --title "Éxito" --msgbox "¡Reporte 'productos.html' generado con éxito!" 6 50
}

# --- FLUJO PRINCIPAL ---
main() {
    inicializar_bd

    if ! menu_autenticacion; then
        clear
        exit 0
    fi

    while true; do
        local opcion
        opcion=$(whiptail --title "Menú Principal - Inventario" \
                          --menu "Usuario activo: $USUARIO_ACTUAL\nSeleccione una acción:" 16 50 6 \
                          "1" "Alta producto" \
                          "2" "Baja producto" \
                          "3" "Editar producto" \
                          "4" "Mostrar inventario" \
                          "5" "Generar reporte HTML" \
                          "6" "Salir" \
                          3>&1 1>&2 2>&3)

        case $opcion in
            1) alta ;;
            2) baja ;;
            3) editar ;;
            4) mostrar ;;
            5) generar_reporte_html ;;
            6)
                registrar_sistema "Cierre de sesión del usuario."
                clear
                break
                ;;
            *)
                clear
                break
                ;;
        esac
    done

    clear
    exit 0
}

main

