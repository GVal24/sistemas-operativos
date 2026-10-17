#!/usr/bin/env bash

# Archivos de persistencia
declare -r PRODUCTOS_FILE="productos.tsv"
declare -r USUARIOS_FILE="usuarios.tsv"

# Constantes para el menú principal
declare -r -i OPCION_ALTA=1
declare -r -i OPCION_BAJA=2
declare -r -i OPCION_EDITAR=3
declare -r -i OPCION_MOSTRAR=4
declare -r -i OPCION_HTML=5
declare -r -i OPCION_SALIR=6

# Inicialización de archivos
touch "$PRODUCTOS_FILE" "$USUARIOS_FILE"

bienvenida() {
    printf "Bienvenido/a al sistema\n\n"
}

# --- AUTENTICACIÓN Y USUARIOS ---
registrar_usuario() {
    declare usuario=""
    declare clave=""
    declare pass_hash=""

    printf "\n=== REGISTRO DE USUARIO ===\n"
    read -rp "Ingrese nombre de usuario: " usuario

    if [[ -z "$usuario" ]]; then
        printf "Error: El nombre de usuario no puede estar vacío.\n"
        return 1
    fi

    if grep -q "^${usuario}"$'\t' "$USUARIOS_FILE"; then
        printf "Error: El usuario '%s' ya se encuentra registrado.\n" "$usuario"
        return 1
    fi

    read -rsp "Ingrese contraseña: " clave
    printf "\n"

    if [[ -z "$clave" ]]; then
        printf "Error: La contraseña no puede estar vacía.\n"
        return 1
    fi

    pass_hash=$(echo -n "$clave" | sha256sum | awk '{print $1}')

    printf "%s\t%s\n" "$usuario" "$pass_hash" >> "$USUARIOS_FILE"
    printf "Usuario '%s' registrado exitosamente.\n" "$usuario"
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

    if grep -q "^${usuario}"$'\t'"${pass_hash}$" "$USUARIOS_FILE"; then
        printf "Acceso concedido. ¡Bienvenido/a %s!\n" "$usuario"
        return 0
    else
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
                return 1
                ;;
            *)
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
        printf "Error: El ID no puede estar vacío.\n"
        return
    fi

    if grep -q "^${id}"$'\t' "$PRODUCTOS_FILE"; then
        printf "Error: El producto con ID '%s' ya existe.\n" "$id"
        return
    fi

    read -rp "Ingrese Nombre: " nombre
    read -rp "Ingrese Precio: " precio

    printf "%s\t%s\t%s\n" "$id" "$nombre" "$precio" >> "$PRODUCTOS_FILE"
    printf "Producto '%s' guardado exitosamente.\n" "$id"
}

baja() {
    declare id=""

    printf "\n=== BAJA DE PRODUCTO ===\n"
    read -rp "Ingrese ID del producto a eliminar: " id

    if ! grep -q "^${id}"$'\t' "$PRODUCTOS_FILE"; then
        printf "Error: El producto con ID '%s' no existe.\n" "$id"
        return
    fi

    grep -v "^${id}"$'\t' "$PRODUCTOS_FILE" > "${PRODUCTOS_FILE}.tmp" && mv "${PRODUCTOS_FILE}.tmp" "$PRODUCTOS_FILE"
    printf "Producto con ID '%s' eliminado.\n" "$id"
}

editar() {
    declare id_buscar=""
    declare nuevo_nombre=""
    declare nuevo_precio=""
    declare temp_file

    printf "\n=== EDITAR PRODUCTO ===\n"
    read -rp "Ingrese ID del producto a editar: " id_buscar

    if ! grep -q "^${id_buscar}"$'\t' "$PRODUCTOS_FILE"; then
        printf "Error: El producto con ID '%s' no existe.\n" "$id_buscar"
        return
    fi

    read -rp "Ingrese nuevo Nombre: " nuevo_nombre
    read -rp "Ingrese nuevo Precio: " nuevo_precio

    temp_file=$(mktemp)
    while IFS=$'\t' read -r col_id col_nombre col_precio; do
        if [[ "$col_id" == "$id_buscar" ]]; then
            printf "%s\t%s\t%s\n" "$col_id" "$nuevo_nombre" "$nuevo_precio" >> "$temp_file"
        else
            printf "%s\t%s\t%s\n" "$col_id" "$col_nombre" "$col_precio" >> "$temp_file"
        fi
    done < "$PRODUCTOS_FILE"

    mv "$temp_file" "$PRODUCTOS_FILE"
    printf "Producto '%s' actualizado correctamente.\n" "$id_buscar"
}

mostrar() {
    printf "\nLISTADO DE PRODUCTOS:\n"
    if [[ ! -s "$PRODUCTOS_FILE" ]]; then
        printf "No hay productos registrados en el inventario.\n"
        return
    fi

    printf "==================================================\n"
    printf "%-10s | %-20s | %-10s\n" "ID" "NOMBRE" "PRECIO"
    printf "==================================================\n"

    while IFS=$'\t' read -r col_id col_nombre col_precio; do
        printf "%-10s | %-20s | $%-10.2f\n" "$col_id" "$col_nombre" "$col_precio"
    done < "$PRODUCTOS_FILE"
    
    printf "==================================================\n"
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
    <h1>Reporte General de Productos</h1>
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

    if [[ -s "$PRODUCTOS_FILE" ]]; then
        while IFS=$'\t' read -r col_id col_nombre col_precio; do
            printf "            <tr><td>%s</td><td>%s</td><td>$%.2f</td></tr>\n" "$col_id" "$col_nombre" "$col_precio" >> "$html_out"
        done < "$PRODUCTOS_FILE"
    fi

    cat << EOF >> "$html_out"
        </tbody>
    </table>
</body>
</html>
EOF

    printf "Reporte '%s' generado con éxito.\n" "$html_out"
}

# --- FLUJO PRINCIPAL ---
main() {
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
                printf "\nSaliendo del programa...\n"
                ;;
            *)
                printf "\nOpción inválida.\n"
                ;;
        esac
    done

    return 0
}

main
